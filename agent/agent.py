import os

from google.adk.agents import LlmAgent, SequentialAgent
from google.adk.models.lite_llm import LiteLlm

MODEL_NAME = os.getenv("MODEL_NAME", "gemma4:e2b")

# Uses Ollama's OpenAI-compatible endpoint via LiteLLM
model = LiteLlm(model=f"openai/{MODEL_NAME}")

# ── Agent 1: Vision Analyzer ─────────────────────────────────────────────────
# Looks at the raw image and extracts everything it can see.
# Stores its output in session state under "vision_analysis".

vision_analyzer = LlmAgent(
    name="VisionAnalyzer",
    model=model,
    description="Extracts all visual information from a screenshot, diagram, or error image",
    instruction="""You are a precise visual analysis engine. Examine the image in the conversation carefully.

Report your findings in this exact format:

**IMAGE TYPE:** (choose one: UI screenshot / error traceback / architecture diagram / code snippet / chart/graph / other)

**VISIBLE ELEMENTS:**
List every visible piece of text, label, button, component, icon, or visual element. Include any error messages or stack traces verbatim.

**STRUCTURE:**
Describe how elements are arranged — layout, hierarchy, connections between components.

**KEY DATA POINTS:**
Call out specific values, error codes, file paths, URLs, version numbers, or identifiers that stand out.

Be exhaustive. Your output is the only input the next agent receives.""",
    output_key="vision_analysis",
)

# ── Agent 2: Explainer / Suggester ───────────────────────────────────────────
# Reads the visual analysis from session state and produces a human-friendly
# explanation with concrete recommended actions.

explainer_suggester = LlmAgent(
    name="ExplainerSuggester",
    model=model,
    description="Explains what the image shows and provides actionable recommendations",
    instruction="""You are a senior technical explainer. A vision agent has analyzed a screenshot and stored its findings in session state under the key 'vision_analysis'.

Using that analysis, respond using this structure:

## What This Shows
Plain-English explanation of what is happening — what system, tool, or context this is from and what the current state is.

## Issues or Highlights
- Any errors, warnings, misconfigurations, or anomalies found
- If nothing is wrong, highlight what is working well or what is notable

## Recommended Next Steps
1. First specific action to take
2. Second specific action to take
3. ...

Keep it developer-friendly: specific, concrete, and actionable. No vague advice.""",
)

# ── Root agent: Sequential pipeline ──────────────────────────────────────────
# VisionAnalyzer runs first → writes analysis to state
# ExplainerSuggester runs second → reads from state, produces final output

root_agent = SequentialAgent(
    name="ScreenshotExplainer",
    description="Analyzes a screenshot with two specialized agents: visual extraction then explanation with suggestions",
    sub_agents=[vision_analyzer, explainer_suggester],
)
