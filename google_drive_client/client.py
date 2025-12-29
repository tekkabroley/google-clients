from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build


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
