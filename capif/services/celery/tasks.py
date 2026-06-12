# celery/tasks.py
import asyncio
import logging
import os
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler

import aiohttp
import pymongo
from bson.codec_options import CodecOptions
from celery import Celery
from config import Config

# Initialize Celery
celery = Celery(
    "notifications",
    broker=f"redis://{os.getenv("REDIS_HOST")}:{os.getenv("REDIS_PORT")}/0",
    backend=f"redis://{os.getenv("REDIS_HOST")}:{os.getenv("REDIS_PORT")}/0"
)

celery.conf.beat_schedule = {
    "check_notifications_collection": {
        "task": "celery.tasks.check_notifications_collection",
        "schedule": 1.0,
        "args": (),
    },
}

celery.conf.timezone = "UTC"
celery.conf.update(worker_hijack_root_logger=False)


# Setting log level
# Set the log level based on the environment variable or default to INFO
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
numeric_level = getattr(logging, log_level, logging.INFO)


def verbose_formatter():
    return logging.Formatter(
        '{"timestamp": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", "function": "%(funcName)s", "line": %(lineno)d, "message": %(message)s}',
        datefmt='%d/%m/%Y %H:%M:%S'
    )


def configure_logging():

    formatter = verbose_formatter()

    console_handler = logging.StreamHandler()
    console_handler.setLevel(numeric_level)
    console_handler.setFormatter(formatter)

    file_handler = RotatingFileHandler(
        filename="celery_logs.log",
        maxBytes=1024 * 1024 * 100,
        backupCount=20
    )
    file_handler.setLevel(numeric_level)
    file_handler.setFormatter(formatter)

    # Root logger configuration
    root_logger = logging.getLogger()
    root_logger.setLevel(numeric_level)
    root_logger.handlers = []
    root_logger.addHandler(console_handler)
    root_logger.addHandler(file_handler)

    # Optional: configure specific logger
    logger = logging.getLogger(__name__)
    logger.setLevel(numeric_level)
    return logger


logger = configure_logging()

# MongoDB Connection
config = Config().get_config()

mongo_uri = f"mongodb://{config['mongo']['user']}:{config['mongo']['password']}@" \
                      f"{config['mongo']['host']}:{config['mongo']['port']}"
client = pymongo.MongoClient(mongo_uri)
notifications_col = client[config['mongo']['db']][config['mongo']['notifications_col']].with_options(codec_options=CodecOptions(tz_aware=True))

def serialize_clean_camel_case(obj):
    res = obj.to_dict()
    res = clean_empty(res)
    res = dict_to_camel_case(res)

    return res

# Function to clean empty values from a dictionary
def clean_empty(d):
    if isinstance(d, dict):
        return {
            k: v
            for k, v in ((k, clean_empty(v)) for k, v in d.items())
            if v is not None or (isinstance(v, list) and len(v) == 0)
        }
    if isinstance(d, list):
        return [v for v in map(clean_empty, d) if v is not None]
    return d

# Function to convert snake_case keys to camelCase
def dict_to_camel_case(my_dict):


        result = {}

        for attr, value in my_dict.items():

            if len(attr.split('_')) != 1:
                my_key = ''.join(word.title() for word in attr.split('_'))
                my_key = ''.join([my_key[0].lower(), my_key[1:]])
            else:
                my_key = attr

            if my_key == "serviceApiCategory":
                my_key = "serviceAPICategory"
            elif my_key == "serviceApiDescriptions":
                my_key = "serviceAPIDescriptions"

            if isinstance(value, list):
                result[my_key] = list(map(
                    lambda x: dict_to_camel_case(x) if isinstance(x, dict) else x, value ))

            elif hasattr(value, "to_dict"):
                result[my_key] = dict_to_camel_case(value)

            elif isinstance(value, dict):
                value = dict_to_camel_case(value)
                result[my_key] = value
            else:
                result[my_key] = value

        return result

# Functions to send a request
async def send_request(url, data):
    async with aiohttp.ClientSession() as session:
        timeout = aiohttp.ClientTimeout(total=10)
        headers = {'content-type': 'application/json'}
        async with session.post(url, json=data, timeout=timeout, headers=headers) as response:
            return await response.text()

async def send(url, data):
    try:
        logger.info(f"Sending notification to {url} with data: {data}")
        response = await send_request(url, data)
        logger.info(response)
    except asyncio.TimeoutError:
        logger.info("Timeout: Request timeout")
    except Exception as e:
        logger.info("An exception occurred sending notification::" + str(e))
        return False

# Periodic task to check the notifications collection
@celery.task(name="celery.tasks.check_notifications_collection")
def my_periodic_task():
    while True:
        try:
            notification_data = notifications_col.find_one_and_delete(
            {"next_report_time": {"$lt": datetime.now(timezone.utc)}}
        )
            if not notification_data:
                break
        except pymongo.errors.AutoReconnect:
            logger.info("MongoDB connection failed. Retrying...")
            continue

        try:
            logger.info(f"Notification for suscription {notification_data["subscription_id"]} ready to send")
            asyncio.run(send(notification_data["url"], notification_data["notification"]))
        except Exception as e:
            logger.info(f"Error sending notification: {e}")

