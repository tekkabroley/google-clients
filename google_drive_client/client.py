from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
import io


class DriveClient:
    def __init__(self, credentials: Credentials):
        self._drive = build("drive", "v3", credentials=credentials)

    def create(self, title: str, mime_type: str, folder_id: str):
        file_metadata = {"name": title, "mimeType": mime_type, "parents": [folder_id]}
        # pylint: disable=maybe-no-member
        file = self._drive.files().create(body=file_metadata, fields="id").execute()
        return file.get("id")

    def share(self, file_id: str, role="commenter", user=None, domain=None):
        permission_id = id

        def callback(request_id, response, exception):
            nonlocal permission_id
            if exception:
                print(exception)
            else:
                permission_id = response.get("id")

        # pylint: disable=maybe-no-member
        batch = self._drive.new_batch_http_request(callback=callback)

        if domain:
            permission = {"type": "domain", "role": role, "domain": domain}
        elif user:
            permission = {"type": "user", "role": role, "emailAddress": user}

        batch.add(
            self._drive.permissions().create(
                fileId=file_id,
                body=permission,
                fields="id",
            )
        )
        batch.execute()

        return permission_id

    def download(self, file_id: str, destination_path: str, export_mime_type: str = None):
        """
        Download a file from Google Drive.
        
        Args:
            file_id: The ID of the file to download
            destination_path: Local path where the file should be saved
            export_mime_type: Optional MIME type for exporting Google Workspace files
                            (e.g., 'application/pdf' for Sheets/Docs)
        
        Returns:
            str: Path to the downloaded file
        """
        # Get file metadata to check MIME type
        # pylint: disable=maybe-no-member
        file_metadata = self._drive.files().get(fileId=file_id, fields='name,mimeType').execute()
        mime_type = file_metadata.get('mimeType', '')
        
        # Determine if this is a Google Workspace file that needs export
        if mime_type.startswith('application/vnd.google-apps.'):
            if not export_mime_type:
                # Default export types for common Google Workspace files
                export_defaults = {
                    'application/vnd.google-apps.spreadsheet': 'application/pdf',
                    'application/vnd.google-apps.document': 'application/pdf',
                    'application/vnd.google-apps.presentation': 'application/pdf',
                }
                export_mime_type = export_defaults.get(mime_type, 'application/pdf')
            
            request = self._drive.files().export_media(fileId=file_id, mimeType=export_mime_type)
        else:
            request = self._drive.files().get_media(fileId=file_id)
        
        # Download the file
        fh = io.FileIO(destination_path, 'wb')
        downloader = MediaIoBaseDownload(fh, request)
        
        done = False
        while not done:
            status, done = downloader.next_chunk()
        
        fh.close()
        return destination_path
