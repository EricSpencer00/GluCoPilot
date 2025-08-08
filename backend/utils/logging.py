import logging
import os
from datetime import datetime
from loguru import logger as loguru_logger
import sys
from core.config import settings

def setup_logging():
    """Setup application logging with loguru"""
    
    # Remove default handler
    loguru_logger.remove()
    
    # Create logs directory if it doesn't exist
    log_dir = os.path.dirname(settings.LOG_FILE)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir)
    
    # Console handler
    loguru_logger.add(
        sys.stderr,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
        level=settings.LOG_LEVEL,
        colorize=True,
        backtrace=True,
        diagnose=True
    )
    
    # File handler
    loguru_logger.add(
        settings.LOG_FILE,
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
        level=settings.LOG_LEVEL,
        rotation="1 day",
        retention="30 days",
        compression="gz",
        backtrace=True,
        diagnose=True
    )
    
    return loguru_logger

def get_logger(name: str):
    """Get a logger instance for a specific module"""
    return loguru_logger.bind(name=name)

# Initialize logging
logger = setup_logging()
