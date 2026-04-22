import json
import requests
import sys
from dotenv import load_dotenv
import os

load_dotenv()

ACCESS_TOKEN = os.getenv("ACCESS_TOKEN")

if not ACCESS_TOKEN:
    raise Exception("Missing ACCESS_TOKEN in .env")

BASE_URL = "https://api.surveymonkey.com/v3"

HEADERS = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Content-Type": "application/json"
}


# =========================
# CREATE SURVEY
# =========================
def create_survey(title):
    res = requests.post(
        f"{BASE_URL}/surveys",
        headers=HEADERS,
        json={"title": title}
    )
    res.raise_for_status()
    data = res.json()

    print("Survey created:", data["id"])
    return data["id"]


# =========================
# CREATE PAGE
# =========================
def create_page(survey_id, title):
    res = requests.post(
        f"{BASE_URL}/surveys/{survey_id}/pages",
        headers=HEADERS,
        json={"title": title}
    )
    res.raise_for_status()
    return res.json()["id"]


# =========================
# CREATE QUESTION
# =========================
def create_question(survey_id, page_id, question_text, answers):
    payload = {
        "headings": [{"heading": question_text}],
        "family": "single_choice",
        "subtype": "vertical",
        "answers": {
            "choices": [{"text": a} for a in answers]
        }
    }

    res = requests.post(
        f"{BASE_URL}/surveys/{survey_id}/pages/{page_id}/questions",
        headers=HEADERS,
        json=payload
    )

    res.raise_for_status()
    return res.json()


# =========================
# CREATE COLLECTOR (FIXED)
# =========================
def create_collector(survey_id):
    res = requests.post(
        f"{BASE_URL}/surveys/{survey_id}/collectors",
        headers=HEADERS,
        json={
            "type": "weblink",
            "name": "Web Link Collector"
        }
    )

    res.raise_for_status()
    data = res.json()

    collector_id = data["id"]   # ✅ FIXED (was your main bug)

    print("Collector created:", collector_id)
    print("Survey Link:", data.get("url"))

    return collector_id


# =========================
# CREATE MESSAGE (SAFE)
# =========================
def create_message(survey_id, collector_id):
    res = requests.post(
        f"{BASE_URL}/surveys/{survey_id}/collectors/{collector_id}/messages",
        headers=HEADERS,
        json={
            "type": "invite",
            "subject": "Survey Invitation",
            "body_text": "Please participate in this survey."
        }
    )

    res.raise_for_status()
    return res.json()["id"]


# =========================
# RECIPIENTS (NOT USED FOR WEBLINK)
# =========================
def send_recipients(survey_id, collector_id, message_id, emails):
    # NOTE: Weblink collectors don't need recipients
    print("Skipping recipients (weblink collector used)")
    return None


# =========================
# LOAD EMAILS
# =========================
def load_emails(file_path):
    with open(file_path, "r") as f:
        return f.readlines()


# =========================
# MAIN
# =========================
def main():
    if len(sys.argv) != 3:
        print("Usage: python survey_script.py survey.json emails.txt")
        sys.exit(1)

    survey_file = sys.argv[1]

    with open(survey_file, "r") as f:
        data = json.load(f)

    for survey_name, pages in data.items():
        print("\nCreating survey:", survey_name)

        survey_id = create_survey(survey_name)

        for page_name, questions in pages.items():
            page_id = create_page(survey_id, page_name)

            for q_text, q_data in questions.items():
                print("Adding question:", q_text)

                create_question(
                    survey_id,
                    page_id,
                    q_text,
                    q_data["Answers"]
                )

        collector_id = create_collector(survey_id)

        print("\n✅ SURVEY CREATED SUCCESSFULLY")
        print("Survey ID:", survey_id)

if __name__ == "__main__":
    main()