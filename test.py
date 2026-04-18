from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
import os

from google_drive_client.client import DriveClient

# Scopes - use read-only for just downloading
SCOPES = ['https://www.googleapis.com/auth/drive.readonly']

def authenticate():
    """Authenticate and return credentials"""
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
    
    return creds

def list_files_in_folder(client, folder_name):
    """List all files in a folder by folder name"""
    # First, find the folder ID
    query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'"
    results = client._drive.files().list(q=query, fields="files(id, name)").execute()
    folders = results.get('files', [])
    
    if not folders:
        print(f"Folder '{folder_name}' not found")
        return []
    
    folder_id = folders[0]['id']
    print(f"Found folder: {folder_name} (ID: {folder_id})")
    
    # List files in the folder
    query = f"'{folder_id}' in parents"
    results = client._drive.files().list(q=query, fields="files(id, name, mimeType)").execute()
    return results.get('files', [])



def main():
    # Authenticate and create DriveClient
    creds = authenticate()
    client = DriveClient(creds)
    
    # Specify your folder name
    folder_name = "test"
    
    # List files in folder
    files = list_files_in_folder(client, folder_name)
    
    if not files:
        print("No files found in folder")
        return
    
    print(f"\nFound {len(files)} files:")
    for f in files:
        print(f"- {f['name']} ({f['mimeType']})")
    
    # Download all files using the new DriveClient.download method
    destination = "./downloads"
    os.makedirs(destination, exist_ok=True)
    
    for file in files:
        file_name = file['name']
        mime_type = file['mimeType']
        
        # Determine file extension based on MIME type
        if mime_type.startswith('application/vnd.google-apps.'):
            # Google Workspace file - will be exported as PDF
            file_path = os.path.join(destination, f"{file_name}.pdf")
            print(f"Exporting {file_name} as PDF...")
        else:
            file_path = os.path.join(destination, file_name)
            print(f"Downloading {file_name}...")
        
        # Use the new download method from DriveClient
        result_path = client.download(file['id'], file_path)
        print(f"✓ Saved to: {result_path}")

if __name__ == '__main__':
    main()
