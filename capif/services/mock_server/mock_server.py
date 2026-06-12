import logging
import os
from logging.handlers import RotatingFileHandler

from flask import Flask, request

app = Flask(__name__)

# Setting log level
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
numeric_level = getattr(logging, log_level, logging.INFO)

# Lista para almacenar las solicitudes recibidas
requests_received = []

def verbose_formatter():
    return logging.Formatter(
        '{"timestamp": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", "function": "%(funcName)s", "line": %(lineno)d, "message": %(message)s}',
        datefmt='%d/%m/%Y %H:%M:%S'
    )


def configure_logging(app):
    del app.logger.handlers[:]
    loggers = [app.logger, ]
    handlers = []
    console_handler = logging.StreamHandler()
    console_handler.setLevel(numeric_level)
    console_handler.setFormatter(verbose_formatter())
    file_handler = RotatingFileHandler(filename="mock_server.log", maxBytes=1024 * 1024 * 100, backupCount=20)
    file_handler.setLevel(numeric_level)
    file_handler.setFormatter(verbose_formatter())
    handlers.append(console_handler)
    handlers.append(file_handler)
  

    for l in loggers:
        for handler in handlers:
            l.addHandler(handler)
        l.propagate = False
        l.setLevel(numeric_level)

@app.route('/testing', methods=['POST', 'GET'])
def index():
    if request.method == 'POST':
        app.logger.debug(request.json)
        app.logger.debug(request.headers)
        requests_received.append(request.json)
    return 'Mock Server is running'

@app.route('/requests_list', methods=['GET','DELETE'])
def requests_list():
    if request.method == 'DELETE':
        requests_received.clear()
    return requests_received


configure_logging(app)

debug_mode = os.getenv('DEBUG_MODE', 'False').lower() in ['true', '1']

if __name__ == '__main__':
    app.run(host=os.environ.get("IP",'0.0.0.0'),port=os.environ.get("PORT",9100), debug=debug_mode)
