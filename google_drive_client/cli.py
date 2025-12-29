import sys
print("CLI module loaded!", file=sys.stderr)
import typer
from google_auth_oauthlib.flow import InstalledAppFlow

from .client import DriveClient
from .credentials import SCOPES, credentials

app = typer.Typer()


@app.command(help="Obtains OAuth credentials for calling Google APIs")
def authorize(
    project_id=typer.Argument(...),
    client_id=typer.Argument(...),
    client_secret=typer.Argument(...),
):
    oauth_client_config = {
        "installed": {
            "client_id": client_id,
            "project_id": project_id,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "client_secret": client_secret,
            "redirect_uris": ["urn:ietf:wg:oauth:2.0:oob", "http://localhost"],
        }
    }

    flow = InstalledAppFlow.from_client_config(oauth_client_config, SCOPES)
    creds = flow.run_local_server(port=50200)

    typer.echo("\nSave the credentials to your google config profile:\n")
    typer.echo(creds.to_json())


@app.command(help="Creates a new empty sheet in the specified folder")
def create(
    sheet_title: str = typer.Argument(..., help="New sheet"),
    folder_id: str = typer.Argument(..., help="Folder location of new sheet"),
):
    print(f"Creating sheet: '{sheet_title}'")
    print(f"In folder: {folder_id}")
    
    drive = DriveClient(credentials())
    # add options for other mime types
    mime_type = "application/vnd.google-apps.spreadsheet"
    
    try:
        file_id = drive.create(sheet_title, mime_type, folder_id)
        # add logic to support other mime types here too
        if file_id:
            print(f"✓ Successfully created file!")
            print(f"✓ File ID: {file_id}")
            print(f"✓ Link: https://docs.google.com/spreadsheets/d/{file_id}")
        else:
            print("✗ No file_id returned - creation may have failed")
            sys.exit(1)
    except Exception as e:
        print(f"✗ Error creating file: {e}")
        sys.exit(1)


@app.command(help="Creates a new empty sheet in the specified folder")
def share(
    file_id: str = typer.Argument(..., help="File ID"),
    role: str = typer.Argument("commenter", help="reader, writer or commenter"),
    domain: str = typer.Option(None, help="Domain to share with"),
    user: str = typer.Option(None, help="User to share with"),
):
    drive = DriveClient(credentials())

    permission_id = drive.share(file_id, role, domain=domain, user=user)
    print(permission_id)


@app.command(help="Lists files in a folder")
def list_files(
    folder_id: str = typer.Argument(..., help="Folder ID to list"),
):
    print(f"Listing files in folder: {folder_id}")
    
    drive = DriveClient(credentials())
    # migrate this logic to client.DriveClient class
    results = drive._drive.files().list(
        q=f"'{folder_id}' in parents and trashed=false",
        fields="files(id, name, mimeType, createdTime)",
        pageSize=100
    ).execute()
    
    files = results.get('files', [])
    
    print(f"Found {len(files)} file(s)")
    
    if not files:
        print(f"✗ No files found in folder {folder_id}")
    else:
        print(f"✓ Files in folder {folder_id}:")
        for file in files:
            print(f"  - {file['name']} (ID: {file['id']})")
            print(f"    Created: {file.get('createdTime')}")
