# Service for MyFitnessPal integration
import requests
from typing import Optional

class MyFitnessPalService:
    BASE_URL = 'https://api.myfitnesspal.com/v2/'

    def __init__(self, access_token: str):
        self.access_token = access_token

    def get_headers(self):
        return {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json',
        }

    def fetch_food_logs(self, start_date: str, end_date: str):
        url = f'{self.BASE_URL}diary?start_date={start_date}&end_date={end_date}'
        response = requests.get(url, headers=self.get_headers())
        response.raise_for_status()
        return response.json()

    # Add more methods as needed for other endpoints
