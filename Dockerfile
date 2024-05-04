FROM mcr.microsoft.com/mssql-tools:latest

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /var/scripts

# Copy all the scripts to the working directory
COPY /scripts .

# Add scripts to the path
ENV PATH=$PATH:/var/scripts/
ENV PATH=$PATH:/opt/mssql-tools/bin/

CMD [ "/opt/mssql-tools/bin/sqlcmd" ]