FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir streamlit pandas sqlalchemy psycopg2-binary
CMD ["streamlit", "run", "app.py", "--server.address=0.0.0.0", "--server.port=8501"]
