# Azure AI Agent Setup Guide

This directory contains the configuration for your Azure AI agent. Follow these steps to set up your production-ready AI assistant.

## Prerequisites

- Azure subscription
- Azure Developer CLI (azd) installed
- Node.js installed
- Visual Studio Code (recommended)

## Quick Setup

1. **Run the setup script**:
   ```bash
   node setup-agent.js
   ```

2. **Deploy infrastructure**:
   ```bash
   azd provision
   ```

3. **Configure your agent**:
   - Open [Azure AI Studio](https://ai.azure.com)
   - Navigate to your AI Hub/Project
   - Create a new agent using the `agent.yaml` configuration
   - Copy the agent ID

4. **Set environment variables**:
   ```bash
   # Copy the template
   cp .env.template .env
   
   # Edit .env with your actual values
   ```

5. **Deploy your application**:
   ```bash
   azd deploy
   ```

## Agent Configuration

The `agent.yaml` file contains the configuration for your AI agent:

- **Name**: Employee Handbook Assistant
- **Model**: GPT-4o
- **Instructions**: Specialized for company policy and HR questions
- **Temperature**: 0.7 (balanced creativity and consistency)

## Environment Variables

Your `.env` file should contain:

```env
AZURE_INFERENCE_API_KEY=your_key_here
AZURE_INFERENCE_SDK_ENDPOINT=https://your-service.openai.azure.com/
AZUREAI_MODEL=gpt-4o
INSTANCE_NAME=your-service-name
AZURE_AI_PROJECT_CONNECTION_STRING=your_connection_string
AZURE_AI_AGENT_ID=your_agent_id
```

## Troubleshooting

### Common Issues

1. **424 Invalid URL Error**:
   - Ensure your Azure AI Projects resource is properly configured
   - Check that your connection string is correct
   - Verify your agent ID exists in Azure AI Studio

2. **Authentication Errors**:
   - Make sure you're logged into Azure CLI: `az login`
   - Verify your subscription has access to Azure AI services
   - Check that your managed identity has proper permissions

3. **Agent Not Found**:
   - Confirm you've created an agent in Azure AI Studio
   - Verify the agent ID matches what's in your environment variables
   - Ensure the agent is in the same AI Hub/Project as your connection string

### Getting Help

- Check the [Azure AI documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/)
- Visit the [Azure AI Studio](https://ai.azure.com) for agent management
- Review the application logs in Azure Portal

## Development

For local development:

1. Create a `.env` file in the `packages/webapi` directory
2. Use the same environment variables as above
3. Run `npm start` to start the development server

## Production Deployment

The infrastructure is configured with:

- **Key Vault**: Stores secrets securely
- **Managed Identity**: Handles authentication automatically
- **Application Insights**: Monitors application performance
- **Auto-scaling**: Adjusts resources based on demand

Your application will automatically use Key Vault references for secrets in production, so you don't need to manually configure environment variables in Azure App Service.
