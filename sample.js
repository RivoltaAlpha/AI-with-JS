import ModelClient, { isUnexpected } from "@azure-rest/ai-inference";
import { AzureKeyCredential } from "@azure/core-auth";
import dotenv from "dotenv"
import fs from  'fs'
import path from  'path'

dotenv.config()

const token = process.env["GITHUB_TOKEN"];
console.log(token)
const endpoint = "https://models.github.ai/inference";
const model = "meta/Llama-4-Maverick-17B-128E-Instruct-FP8";

const image = path.join(process.cwd(),
'contoso_layout_sketch.jpg'
)
const imageBase64 = fs.readFileSync(image).toString('base64')

export async function main() {

  const client = ModelClient(
    endpoint,
    new AzureKeyCredential(token),

    console.log(AzureKeyCredential)
  );

  const response = await client.path("/chat/completions").post({
    body: {
      messages: [
        { role:"system", content: "You are a skilled React dev." },
        { role:"user", content: "What is the capital of France?" }
      ],
      temperature: 1.0,
      top_p: 1.0,
      max_tokens: 1000,
      model: model
    }
  });

  if (isUnexpected(response)) {
    console.log(response)
    throw response.body.error;
  }

  console.log(response.body.choices[0].message.content);
}

main().catch((err) => {
  console.error("The sample encountered an error:", err);
});

