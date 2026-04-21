# Use Python 3.12 slim as the base
FROM python:3.12-slim

# Prevent Python from writing pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    wget \
    make \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvbin/uv
ENV PATH="/uvbin:${PATH}"

# Install Bruin
RUN curl -LsSf https://getbruin.com/install/cli | sh
ENV PATH="/root/.local/bin:${PATH}"

# Set the working directory
WORKDIR /app

# Copy dependency files first for layer caching
COPY pyproject.toml uv.lock ./
RUN uv pip install --system -r pyproject.toml

# Copy the rest of the application
COPY . .

# Default command: show help or targets
CMD ["bash"]