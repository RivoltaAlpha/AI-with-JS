import { AIProjectsClient } from "@azure/ai-projects";
import { DefaultAzureCredential } from "@azure/identity";
import dotenv from "dotenv";

dotenv.config();

const agentThreads = {};

export class AgentService {
  constructor() {
    // Use environment variables instead of hardcoded values
    const connectionString = process.env.AZURE_AI_PROJECT_CONNECTION_STRING;
    const agentId = process.env.AZURE_AI_AGENT_ID;
    
    if (!connectionString || connectionString === "<YOUR_CONNECTION_STRING>") {
      console.warn("Azure AI Project connection string not configured. Please set AZURE_AI_PROJECT_CONNECTION_STRING environment variable.");
      this.client = null;
      this.agentId = null;
      return;
    }
    
    if (!agentId || agentId === "<YOUR_AGENT_ID>") {
      console.warn("Azure AI Agent ID not configured. Please set AZURE_AI_AGENT_ID environment variable.");
      this.client = null;
      this.agentId = null;
      return;
    }
    
    try {
      this.client = AIProjectsClient.fromConnectionString(
        connectionString,
        new DefaultAzureCredential()
      );
      this.agentId = agentId;
      console.log("Azure AI Projects client initialized successfully");
    } catch (error) {
      console.error("Failed to initialize Azure AI Projects client:", error);
      this.client = null;
      this.agentId = null;
    }
  }

  async getOrCreateThread(sessionId) {
    if (!this.client) {
      throw new Error("Azure AI Projects client not initialized");
    }
    
    if (!agentThreads[sessionId]) {
      const thread = await this.client.agents.createThread();
      agentThreads[sessionId] = thread.id;
      return thread.id;
    }
    return agentThreads[sessionId];
  }

  async processMessage(sessionId, message) {
    // Check if the client is properly initialized
    if (!this.client || !this.agentId) {
      console.warn("Azure AI Projects client not configured. Falling back to basic response.");
      return {
        reply: "I'm currently not connected to the AI agent service. Please configure the Azure AI Projects connection.",
      };
    }
    
    try {
      const threadId = await this.getOrCreateThread(sessionId);

      const createdMessage = await this.client.agents.createMessage(threadId, {
        role: "user",
        content: message,
      });

      let run = await this.client.agents.createRun(threadId, this.agentId);
      
      while (run.status === "queued" || run.status === "in_progress") {
        await new Promise((resolve) => setTimeout(resolve, 1000));
        run = await this.client.agents.getRun(threadId, run.id);
      }
      
      if (run.status !== "completed") {
        console.error(`Run failed with status: ${run.status}`);
        return {
          reply: `Sorry, I encountered an error (${run.status}). Please try again.`,
        };
      }
      
      const messages = await this.client.agents.listMessages(threadId);
      
      const assistantMessages = messages.data
        .filter(msg => msg.role === "assistant")
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
      
      if (assistantMessages.length === 0) {
        return { 
          reply: "I don't have a response at this time. Please try again.",
        };
      }

      let responseText = "";
      for (const contentItem of assistantMessages[0].content) {
        if (contentItem.type === "text") {
          responseText += contentItem.text.value;
        }
      }
      
      return {
        reply: responseText,
      };
    } catch (error) {
      console.error("Agent error:", error);
      return {
        reply: "Sorry, I encountered an error processing your request. Please try again.",
      };
    }
  }
}