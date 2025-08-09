# Fine-tuning Guide for GluCoPilot's AI Model (future reference)

## Overview

Fine-tuning the model will help it generate more accurate, specific, and clinically-sound diabetes management recommendations. This process involves creating a dataset of example inputs and outputs, then training the model on these examples.

## Steps for Fine-tuning

### 1. Create a Training Dataset

Create a JSONL file with examples in the following format:

```jsonl
{"messages": [{"role": "system", "content": "You are a diabetes management assistant that provides personalized, evidence-based recommendations."}, {"role": "user", "content": "Patient Profile:\n- Age: 35\n- Gender: Male\n- Diabetes Type: 1\n- Target Range: 70-180 mg/dL\n- Insulin-to-Carb Ratio: 1:10\n- Correction Factor: 50\n\nCurrent Glucose Patterns (24-hour analysis):\n- Average Glucose: 165.5 mg/dL\n- Time in Range: 65.3%\n- Glucose Variability: 32.1%\n- Frequent highs (>250): 15.2%\n- Frequent lows (<70): 8.1%\n\n..."}, {"role": "assistant", "content": "Based on your data, here are my recommendations:\n\n1. Title: Pre-bolus for high-carb meals\nDescription: Your post-meal glucose spikes are averaging 85 mg/dL. Consider taking insulin 15-20 minutes before eating high-carb meals (>40g) to reduce these spikes.\nCategory: insulin\nPriority: high\nAction: Take bolus insulin 15-20 minutes before high-carb meals\nTiming: Before breakfast and dinner\n\n2. Title: Adjust overnight basal rate\nDescription: Your overnight glucose levels show a steady rise between 2-4am, indicating dawn phenomenon. Consider increasing your basal rate by 10% during this window.\nCategory: insulin\nPriority: medium\nAction: Increase basal insulin by 10% between 1-5am\nTiming: Every night\n\n..."}]}
```

Include at least 50-100 diverse examples covering:
- Different diabetes types
- Various patterns (dawn phenomenon, exercise impact, etc.)
- Multiple recommendation categories
- Different severity levels
- Various patient demographics

### 2. Prepare for Fine-tuning

Since we're using the gpt-oss-20b model through Fireworks, we'll need to:

1. Split data into training and validation sets
2. Format data according to Fireworks' fine-tuning requirements

### 3. Fine-tune the Model

Use Fireworks' API to fine-tune the model:

```python
import requests
import json

# API endpoint
API_URL = "https://api.fireworks.ai/v1/fine-tuning/jobs"

# API key
API_KEY = "your_fireworks_api_key"

# Request headers
headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Request body
data = {
    "base_model": "openai/gpt-oss-20b",
    "training_file": "your_training_file_id",
    "validation_file": "your_validation_file_id",
    "hyperparameters": {
        "epochs": 3,
        "batch_size": 4,
        "learning_rate": 1e-5
    }
}

# Send request
response = requests.post(API_URL, headers=headers, json=data)
print(response.json())
```

### 4. Evaluate the Fine-tuned Model

Compare the fine-tuned model against the base model using:
- BLEU, ROUGE scores for text generation quality
- Domain-specific metrics for clinical accuracy
- A/B testing with diabetes educators

### 5. Deploy the Fine-tuned Model

1. Update your `.env` file with the new model ID
2. Test thoroughly with diverse patient scenarios
3. Monitor performance in production

## Best Practices for Diabetes Management Fine-tuning

1. **Clinical Accuracy**: Have diabetes educators review training examples
2. **Varied Scenarios**: Include all common diabetes patterns
3. **Specificity**: Train on highly specific, actionable recommendations
4. **Safety**: Include examples of when to recommend seeking medical attention
5. **Diverse Data**: Cover Type 1, Type 2, LADA, gestational diabetes

## Data Collection Strategy

1. Anonymize real patient data patterns
2. Partner with CDEs (Certified Diabetes Educators) to create realistic scenarios
3. Use published case studies from diabetes journals
4. Include edge cases like sick days, travel, and exercise

## Example Format for Training Data

```
Patient Profile:
[patient demographics and settings]

Current Glucose Patterns:
[key metrics and patterns]

Recent Data Summary:
[recent monitoring, insulin, food data]

Specific Patterns:
[identified patterns from data]
```

Expected output format:
```
1. Title: [clear title]
   Description: [detailed explanation]
   Category: [category]
   Priority: [priority level]
   Action: [specific action]
   Timing: [when to take action]

2. [second recommendation]
...
```
