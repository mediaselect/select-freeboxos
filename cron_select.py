import logging
import json
import os

from subprocess import Popen, PIPE
from datetime import datetime
from logging.handlers import RotatingFileHandler


user = os.getenv("USER")

log_file = "/home/" + user + "/.local/share/select_freeboxos/logs/select_freeboxos.log"
max_bytes = 10 * 1024 * 1024  # 10 MB
backup_count = 5
log_handler = RotatingFileHandler(log_file, maxBytes=max_bytes, backupCount=backup_count)

log_format = '%(asctime)s %(levelname)s %(message)s'
log_datefmt = '%d-%m-%Y %H:%M:%S'
formatter = logging.Formatter(log_format, log_datefmt)

log_handler.setFormatter(formatter)

logger = logging.getLogger()
logger.addHandler(log_handler)

logger.setLevel(logging.INFO)
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s %(levelname)s %(message)s',
                    datefmt='%d-%m-%Y %H:%M:%S',
                    handlers=[log_handler])

def get_file_modification_time(file_path):
    try:
        mod_time = os.path.getmtime(file_path)
        return datetime.fromtimestamp(mod_time)
    except FileNotFoundError:
        logger.error(f"File not found: {file_path}")
        return None

def remove_items(INFO_PROGS, INFO_PROGS_LAST, PROGS_TO_RECORD):
    # Remove items already set to be recorded
    try:
        with open(INFO_PROGS, 'r') as f:
            source_data = json.load(f)
    except FileNotFoundError:
        logging.error(
        "No info_progs.json file. Need to check curl command or "
        "internet connection. Exit programme."
        )
        exit()
    except json.decoder.JSONDecodeError:
        logging.error(
        "JSONDecodeError in info_progs.json file. Need to check curl command or "
        "internet connection. Exit programme."
        )
        exit()

    try:
        with open(INFO_PROGS_LAST, 'r') as f:
            items_to_remove = json.load(f)
    except FileNotFoundError:
        items_to_remove = []

    modified_data = [item for item in source_data if item not in items_to_remove]

    with open(PROGS_TO_RECORD, 'w') as f:
        json.dump(modified_data, f, indent=4)


INFO_PROGS = "/home/" + user + "/.local/share/select_freeboxos/info_progs.json"
INFO_PROGS_LAST = ("/home/" + user + "/.local/share/select_freeboxos/"
                   "info_progs_last.json")
PROGS_TO_RECORD = ("/home/" + user + "/.local/share/select_freeboxos/"
                   "progs_to_record.json")

cmd = "ls /home/" + user + "/.netrc"
ls_netrc = Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True)
stdout, stderr = ls_netrc.communicate()
netrc = stdout.decode("utf-8")[:-1]

if netrc != "/home/" + user + "/.netrc":
    logging.error("No .netrc file. Exit program")
    exit()

cmd = ("stat -c %Y-%s /home/" + user + "/.local/share/select_"
       "freeboxos/info_progs.json")
stat_cmd = Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True)
stdout, stderr = stat_cmd.communicate()
error_file = stderr.decode().strip()

if error_file == "":
    info_file = stdout.decode().strip().split("-")
    time_file = datetime.fromtimestamp(int(info_file[0]))
    time_diff = datetime.now() - time_file
    size_file = int(info_file[1])

info_progs_last_mod_time = get_file_modification_time(INFO_PROGS_LAST)

if info_progs_last_mod_time is None or info_progs_last_mod_time.date() < datetime.now().date():
    if error_file != "" or time_diff.total_seconds() > 1800 or size_file == 0:
        cmd = ("echo --- crontab time: $(date) >> /home/" + user + "/.local/share/select_freeboxos"
        "/logs/cron_curl.log && curl -H 'Accept: application/json;indent=4' -n "
        "https://www.media-select.fr/api/v1/progweek > /home/" + user + "/.local/share"
        "/select_freeboxos/info_progs.json 2>> /home/" + user + "/.local/share"
        "/select_freeboxos/logs/cron_curl.log")
        curl_cmd = Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True)
        stdout, stderr = curl_cmd.communicate()

        remove_items(INFO_PROGS, INFO_PROGS_LAST, PROGS_TO_RECORD)

        cmd = "cd /home/" + user + "/select-freeboxos && bash cron_freeboxos_app.sh"
        Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True)
