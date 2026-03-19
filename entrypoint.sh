#!/bin/bash
set -e

echo "🚀 QuantumAI Stack başlatılıyor..."
echo "Node: $(hostname)"
echo "Python: $(python3 --version)"

# Health check for dependencies
echo "📊 Sistem gereksinimleri kontrol ediliyor..."

# Check Redis connection (if available)
if command -v redis-cli &> /dev/null; then
    if redis-cli -h ${REDIS_HOST:-redis} -p ${REDIS_PORT:-6379} ping &> /dev/null; then
        echo "✅ Redis bağlantısı OK"
    else
        echo "⚠️  Redis erişilemez (optional)"
    fi
fi

# Check database connection (if available)
if [ ! -z "$DATABASE_URL" ]; then
    echo "📦 Database URL configured: ${DATABASE_URL%:*}://***/***"
fi

# Start Flask/Gunicorn application
echo "🌐 Web uygulaması başlatılıyor..."
cd /app || exit 1

# Use Gunicorn if available, fallback to Flask dev server
if command -v gunicorn &> /dev/null; then
    exec gunicorn \
        --bind 0.0.0.0:${PORT:-5000} \
        --workers ${GUNICORN_WORKERS:-4} \
        --worker-class uvicorn.workers.UvicornWorker \
        --timeout 120 \
        --access-logfile - \
        --error-logfile - \
        app:app
else
    echo "ℹ️  Gunicorn not found, using Flask development server"
    exec python3 -m flask run --host 0.0.0.0 --port ${PORT:-5000}
fi
