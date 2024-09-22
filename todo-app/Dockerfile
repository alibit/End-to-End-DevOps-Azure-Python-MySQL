FROM python:3.9

WORKDIR /usr/src/app

RUN apt-get update && \
  apt-get install -y --no-install-recommends curl apt-transport-https gnupg && \
  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
  curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/msprod.list && \
  apt-get update && \
  ACCEPT_EULA=Y apt-get install -y msodbcsql17 unixodbc-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* || true

RUN apt-get clean

COPY . .

RUN ln -s /usr/bin/python3 /usr/bin/python
RUN pip3 install --upgrade pip

RUN pip3 install --no-cache-dir -r requirements.txt

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
