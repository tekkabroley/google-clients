import json
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2 import service_account
from google.oauth2.credentials import Credentials
from pydantic_settings import BaseSettings


class InvalidCredentialsError(Exception):
    pass


SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets.readonly",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive.metadata.readonly",
    "https://www.googleapis.com/auth/drive.metadata",
    "https://www.googleapis.com/auth/drive.file",
    "https://www.googleapis.com/auth/drive",
]

FILE_PREFIX = "file://"


class Settings(BaseSettings):
    """
    Config property google_client_credentials must be either a path prefixed by file://
    or a credentials object in JSON format
    """

    google_client_credentials: str

    class Config:
        env_file = ".env"


settings = Settings()


def credentials():
    credentials_string = settings.google_client_credentials

    if credentials_string.startswith(FILE_PREFIX):
        path = Path(credentials_string.split(FILE_PREFIX)[1])
        if not path.is_file():
            raise ValueError(f"Google credentials file not found: {path}")
        credentials_string = path.read_text()

    credentials_json = json.loads(credentials_string)

    if credentials_json["type"] == "service_account":
        credentials = service_account.Credentials.from_service_account_info(
            credentials_json, scopes=SCOPES
        )
    else:
        credentials = Credentials.from_authorized_user_info(credentials_json, SCOPES)

    if not credentials.valid:
        try:
            credentials.refresh(Request())
            # print("Refreshed access token")
        except Exception:
            raise InvalidCredentialsError("Failed to refresh Google API credentials")

    return credentials
