#!/usr/bin/env node

/**
 * Azure AI Agent Setup Script
 * 
 * This script helps you set up your Azure AI agent after infrastructure deployment.
 * It will guide you through the process of creating an agent in Azure AI Studio
 * and configuring your environment variables.
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';

const execAsync = promisify(exec);

async function main() {
  console.log('🚀 Azure AI Agent Setup');
  console.log('========================\n');

  // Check if azd is available
  try {
    await execAsync('azd version');
    console.log('✅ Azure Developer CLI is available\n');
  } catch (error) {
    console.error('❌ Azure Developer CLI not found. Please install azd first.');
    console.error('Visit: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd');
    process.exit(1);
  }

  console.log('📋 Steps to complete setup:\n');

  console.log('1. Deploy infrastructure:');
  console.log('   azd provision\n');

  console.log('2. Get Azure AI service details:');
  console.log('   azd env get-values\n');

  console.log('3. Create an AI agent in Azure AI Studio:');
  console.log('   - Go to https://ai.azure.com');
  console.log('   - Navigate to your AI Hub/Project');
  console.log('   - Create a new Agent using the agent.yaml configuration');
  console.log('   - Copy the Agent ID\n');

  console.log('4. Update environment variables:');
  console.log('   - Copy .env.template to .env');
  console.log('   - Fill in the values from steps 2 and 3\n');

  console.log('5. Deploy your application:');
  console.log('   azd deploy\n');

  console.log('📝 For detailed instructions, see the README.md file.');
  
  // Check if .env.template exists
  const envTemplatePath = path.join(process.cwd(), '.env.template');
  if (fs.existsSync(envTemplatePath)) {
    console.log('\n💡 Found .env.template file. You can copy this to .env and fill in your values.');
  }
}

main().catch(console.error);
