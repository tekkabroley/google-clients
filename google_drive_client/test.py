from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
import os
import io

# Scopes - use read-only for just downloading
SCOPES = ['https://www.googleapis.com/auth/drive.readonly']

def authenticate():
    """Authenticate and return the Drive service"""
    creds = None
    
    # Token.json stores user's access and refresh tokens
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    # If no valid credentials, let user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save credentials for next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    
    return build('drive', 'v3', credentials=creds)

def list_files_in_folder(service, folder_name):
    """List all files in a folder by folder name"""
    # First, find the folder ID
    query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'"
    results = service.files().list(q=query, fields="files(id, name)").execute()
    folders = results.get('files', [])
    
    if not folders:
        print(f"Folder '{folder_name}' not found")
        return []
    
    folder_id = folders[0]['id']
    print(f"Found folder: {folder_name} (ID: {folder_id})")
    
    # List files in the folder
    query = f"'{folder_id}' in parents"
    results = service.files().list(q=query, fields="files(id, name, mimeType)").execute()
    return results.get('files', [])

def download_file(service, file_id, file_name, destination_path):
    """Download a file from Google Drive"""
    request = service.files().get_media(fileId=file_id)
    
    file_path = os.path.join(destination_path, file_name)
    fh = io.FileIO(file_path, 'wb')
    downloader = MediaIoBaseDownload(fh, request)
    
    done = False
    print(f"Downloading {file_name}...")
    while done is False:
        status, done = downloader.next_chunk()
        print(f"Download {int(status.progress() * 100)}%")
    
    print(f"Downloaded to: {file_path}")

def main():
    # Authenticate
    service = authenticate()
    
    # Specify your folder name
    folder_name = "YourFolderName"
    
    # List files in folder
    files = list_files_in_folder(service, folder_name)
    
    if not files:
        print("No files found in folder")
        return
    
    print(f"\nFound {len(files)} files:")
    for f in files:
        print(f"- {f['name']}")
    
    # Download all files (or specify which one)
    destination = "./downloads"
    os.makedirs(destination, exist_ok=True)
    
    for file in files:
        download_file(service, file['id'], file['name'], destination)

if __name__ == '__main__':
    main()
