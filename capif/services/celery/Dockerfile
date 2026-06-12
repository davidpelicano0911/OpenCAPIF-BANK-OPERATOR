FROM python:3-slim-bullseye

WORKDIR /celery

COPY requirements.txt /celery/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /celery

RUN chmod +x /celery/start_celery.sh

CMD ["/celery/start_celery.sh"]
