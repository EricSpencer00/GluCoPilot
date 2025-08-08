#!/bin/bash

# GluCoPilot Setup Script
# This script sets up the complete development environment

set -e

echo "🚀 Setting up GluCoPilot Development Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
    if [[ $(echo "$python_version >= 3.9" | bc -l) -eq 0 ]]; then
        print_error "Python 3.9+ is required, found $python_version"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is required but not installed"
        exit 1
    fi
    
    node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ $node_version -lt 18 ]]; then
        print_error "Node.js 18+ is required, found version $node_version"
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is required but not installed"
        exit 1
    fi
    
    echo "✅ All prerequisites satisfied"
}

# Setup backend
setup_backend() {
    print_step "Setting up Python backend..."
    
    cd backend
    
    # Create virtual environment
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
        echo "Created Python virtual environment"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install dependencies
    pip install -r requirements.txt
    
    # Create .env file from template
    if [[ ! -f ".env" ]]; then
        cp .env.example .env
        print_warning "Created .env file from template. Please update with your actual credentials."
    fi
    
    # Create logs directory
    mkdir -p logs
    
    # Create models directory for AI models
    mkdir -p models
    
    # Run database migrations
    if [[ -f "alembic.ini" ]]; then
        alembic upgrade head
        echo "Database migrations completed"
    else
        print_warning "No Alembic configuration found. Database setup may be incomplete."
    fi
    
    cd ..
    echo "✅ Backend setup completed"
}

# Setup frontend
setup_frontend() {
    print_step "Setting up React Native frontend..."
    
    cd frontend
    
    # Install dependencies
    npm install
    
    # Install Expo CLI if not present
    if ! command -v expo &> /dev/null; then
        npm install -g @expo/cli
        echo "Installed Expo CLI"
    fi
    
    # Create assets directory
    mkdir -p assets
    
    cd ..
    echo "✅ Frontend setup completed"
}

# Setup AI models
setup_ai() {
    print_step "Setting up AI models..."
    
    cd backend
    source venv/bin/activate
    
    # Download default model (if local model is preferred)
    python -c "
import os
from transformers import AutoTokenizer, AutoModelForCausalLM
from sentence_transformers import SentenceTransformer

print('Downloading default AI models...')

# Download text generation model
try:
    tokenizer = AutoTokenizer.from_pretrained('microsoft/DialoGPT-medium')
    model = AutoModelForCausalLM.from_pretrained('microsoft/DialoGPT-medium')
    
    # Save to local models directory
    os.makedirs('models/DialoGPT-medium', exist_ok=True)
    tokenizer.save_pretrained('models/DialoGPT-medium')
    model.save_pretrained('models/DialoGPT-medium')
    print('✅ Text generation model downloaded')
except Exception as e:
    print(f'⚠️  Warning: Could not download text generation model: {e}')

# Download embedding model
try:
    embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
    embedding_model.save('models/sentence-transformer')
    print('✅ Embedding model downloaded')
except Exception as e:
    print(f'⚠️  Warning: Could not download embedding model: {e}')
"
    
    cd ..
    echo "✅ AI models setup completed"
}

# Create development database
setup_database() {
    print_step "Setting up development database..."
    
    cd backend
    source venv/bin/activate
    
    # Initialize database with sample data
    python -c "
from core.database import engine, Base
from models import user, glucose, insulin, food, analysis, recommendations, health_data

print('Creating database tables...')
Base.metadata.create_all(bind=engine)
print('✅ Database tables created')
"
    
    cd ..
    echo "✅ Database setup completed"
}

# Generate sample data for development
generate_sample_data() {
    print_step "Generating sample development data..."
    
    cd backend
    source venv/bin/activate
    
    python -c "
import sys
sys.path.append('.')
from scripts.generate_sample_data import generate_sample_data
generate_sample_data()
print('✅ Sample data generated')
"
    
    cd ..
}

# Create desktop shortcuts (macOS)
create_shortcuts() {
    if [[ '$OSTYPE' == 'darwin'* ]]; then
        print_step "Creating development shortcuts..."
        
        # Create start script
        cat > start_glucopilot.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "Starting GluCoPilot Development Environment..."

# Start backend
echo "Starting backend server..."
cd backend
source venv/bin/activate
uvicorn main:app --reload --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!
cd ..

# Wait for backend to start
sleep 5

# Start frontend
echo "Starting frontend..."
cd frontend
npm start &
FRONTEND_PID=$!
cd ..

echo "✅ GluCoPilot is starting..."
echo "Backend: http://localhost:8000"
echo "Frontend: http://localhost:19006"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for interrupt
trap "kill $BACKEND_PID $FRONTEND_PID; exit" INT
wait
EOF
        
        chmod +x start_glucopilot.sh
        echo "✅ Created start_glucopilot.sh script"
    fi
}

# Main setup function
main() {
    echo "🩺 GluCoPilot - AI-Powered Diabetes Management"
    echo "Setting up development environment..."
    echo ""
    
    check_prerequisites
    setup_backend
    setup_frontend
    setup_ai
    setup_database
    generate_sample_data
    create_shortcuts
    
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "Quick Start:"
    echo "  1. Update backend/.env with your Dexcom credentials"
    echo "  2. Run: ./start_glucopilot.sh"
    echo "  3. Open http://localhost:19006 for mobile app"
    echo "  4. Backend API available at http://localhost:8000"
    echo ""
    echo "Documentation:"
    echo "  • API Docs: http://localhost:8000/docs"
    echo "  • Project README: ./README.md"
    echo "  • Contributing Guide: ./docs/CONTRIBUTING.md"
    echo ""
    echo "Happy coding! 🚀"
}

# Run main function
main "$@"
