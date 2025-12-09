import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_user: str
    db_pass: str
    db_host: str
    db_port: int
    db_name: str
    ha_url: str
    ha_websocket_url: str
    ha_token: str
    gemini_api_key: str
    gemini_base_url: str

    class Config:
        env_file = ".env"


settings = Settings()
