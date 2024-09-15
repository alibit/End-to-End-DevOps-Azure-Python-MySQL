FROM python:3.9

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y \
  curl \
  apt-transport-https \
  unixodbc \
  unixodbc-dev \
  gnupg2

RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
  && curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update \
  && ACCEPT_EULA=Y apt-get install -y msodbcsql17

RUN apt-get clean

COPY . .

RUN pip install --upgrade pip

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 5000

CMD ["python", "./app.py"]
