FROM python:3.12-slim
WORKDIR /srv/rossettaai

# Copy context (includes optional requirements.txt)
COPY . .

# Install only if requirements file exists
RUN if [ -f requirements.txt ]; then \
			pip install --no-cache-dir -r requirements.txt || true ; \
		fi

ENV SERVICE_NAME=RossettaAI
CMD ["python","app/main.py"]
