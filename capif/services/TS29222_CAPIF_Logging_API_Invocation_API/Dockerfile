FROM python:3-slim-bullseye

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY requirements.txt /usr/src/app/requirements.txt

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    build-essential \
    linux-headers-generic \
    ca-certificates \
    libffi-dev \
    libssl-dev \
    libxslt1-dev && \
    rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . /usr/src/app

EXPOSE 8080

CMD ["sh", "prepare_logging.sh"]