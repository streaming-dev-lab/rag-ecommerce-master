#!/usr/bin/env python
import os
import re
import json
from pathlib import Path
from typing import Any, Callable, Dict, Union
from typing_extensions import TypedDict

import chromadb
from fastapi import FastAPI, Request
from langchain.chat_models import ChatOpenAI
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_community.chat_message_histories import FileChatMessageHistory
from langchain.prompts import ChatPromptTemplate
from langchain_chroma import Chroma
from langchain_core.output_parsers import StrOutputParser
from langchain_openai import OpenAIEmbeddings
from langchain_core.runnables import ConfigurableFieldSpec
from langchain_core.runnables.history import RunnableWithMessageHistory
from langserve import add_routes
from langchain_core.runnables import RunnablePassthrough


def _is_valid_identifier(value: str) -> bool:
    """Check if the value is a valid identifier."""
    valid_characters = re.compile(r"^[a-zA-Z0-9-_]+$")
    return bool(valid_characters.match(value))


def create_session_factory(
    base_dir: Union[str, Path],
) -> Callable[[str], BaseChatMessageHistory]:
    """Create a factory that can retrieve chat histories."""
    base_dir_ = Path(base_dir) if isinstance(base_dir, str) else base_dir
    if not base_dir_.exists():
        base_dir_.mkdir(parents=True)

    def get_chat_history(user_id: str, conversation_id: str) -> FileChatMessageHistory:
        """Get a chat history from a user id and conversation id."""
        if not _is_valid_identifier(user_id):
            user_id = "default_user"
        if not _is_valid_identifier(conversation_id):
            conversation_id = "default"

        user_dir = base_dir_ / user_id
        if not user_dir.exists():
            user_dir.mkdir(parents=True)
        file_path = user_dir / f"{conversation_id}.json"
        return FileChatMessageHistory(str(file_path))

    return get_chat_history


app = FastAPI(
    title="LangChain Server",
    version="1.0",
    description="A simple api server using Langchain's Runnable interfaces",
)
embeddings = OpenAIEmbeddings(model="text-embedding-3-large")

client = chromadb.HttpClient(host=os.environ['CHROMA_HOST'], port=8000)
vstore = Chroma(
    client=client,
    collection_name="products",
    embedding_function=embeddings
)

retriever = vstore.as_retriever()

# convert obj to str from response


def safe_str(obj):
    if obj is None:
        return ""

    try:
        if hasattr(obj, '__dict__'):  # For object instances
            return json.dumps(obj.__dict__, default=str)
        elif isinstance(obj, (dict, list)):  # For dictionaries and lists
            return json.dumps(obj, default=str)
        else:
            return str(obj)  # For primitive types
    except:
        return f"[Object of type {type(obj).__name__}]"


def format_chat_history(history):
    if not history:
        return ""

    formatted = ""
    for msg in history:
        try:
            if isinstance(msg, dict):
                role = msg.get("role", "unknown")
                content = msg.get("content", "")
                formatted += f"{role.capitalize()}: {content}\n"
            elif hasattr(msg, "type") and hasattr(msg, "content"):
                role = getattr(msg, "type", "unknown")
                content = getattr(msg, "content", "")
                formatted += f"{role.capitalize()}: {content}\n"
            else:
                formatted += f"Message: {safe_str(msg)}\n"
        except:
            formatted += "Error formatting message\n"

    return formatted


def format_documents(docs):
    formatted = ""
    try:
        for i, doc in enumerate(docs):
            formatted += f"Document {i+1}:\n"

            # Extract content
            if hasattr(doc, "page_content"):
                formatted += f"Content: {doc.page_content}\n"

            # Extract metadata
            if hasattr(doc, "metadata"):
                meta = doc.metadata
                formatted += "Metadata:\n"
                for key, value in meta.items():
                    formatted += f"- {key}: {value}\n"

            formatted += "\n"
    except:
        formatted = f"Error formatting documents: {safe_str(docs)}"

    return formatted


template = """As an assistant to an ecommerce shop, answer the question asked by a visitor based on the following:

Previous conversation:
{history_str}

Context from product database:
{context_str}

If the question is about a product, you should find the url in the metadata of each element of the context, then provide this url in your answer.
If the question refers to something mentioned earlier (like "how much is that?"), use the previous conversation to understand what was referred to, but do not reuse the answer from the previous conversation to respond again.
If you find options from the context that are irrelevant, you shall filter it out.

Question: {question_str}
"""

prompt = ChatPromptTemplate.from_template(template)
model = ChatOpenAI(temperature=0, model="gpt-4o-mini", streaming=True)


def process_input(input_data):
    if isinstance(input_data, dict):
        question = input_data.get("question", "")
    else:
        question = str(input_data)

    question_str = safe_str(question)

    # Get history from the context (if available), or use an empty history
    history = input_data.get("history", []) if isinstance(
        input_data, dict) else []
    history_str = format_chat_history(history)

    # Get context by querying the retriever
    try:
        docs = retriever.invoke(question_str)
        context_str = format_documents(docs)
    except Exception as e:
        context_str = f"Error retrieving context: {str(e)}"

    return {
        "question_str": question_str,
        "history_str": history_str,
        "context_str": context_str
    }


chain = (
    process_input
    | prompt
    | model
    | StrOutputParser()
)

# https://github.com/langchain-ai/langserve/blob/main/examples/chat_with_persistence_and_user/server.py


class InputChat(TypedDict):
    """Input for the chat endpoint."""

    question: str
    """Human input"""


chain_with_history = RunnableWithMessageHistory(
    chain,
    create_session_factory("chat_histories"),
    input_messages_key="question",
    history_messages_key="history",
    history_factory_config=[
        ConfigurableFieldSpec(
            id="user_id",
            annotation=str,
            name="User ID",
            description="Unique identifier for the user.",
            default="default_user",
            is_shared=True,
        ),
        ConfigurableFieldSpec(
            id="conversation_id",
            annotation=str,
            name="Conversation ID",
            description="Unique identifier for the conversation.",
            default="default",
            is_shared=True,
        ),
    ],
).with_types(input_type=InputChat)

# Add req to cookies user ID


def _per_request_config_modifier(
    config: Dict[str, Any], request: Request
) -> Dict[str, Any]:
    config = config.copy()
    configurable = config.get("configurable", {})

    user_id = request.cookies.get("user_id")
    if not user_id:
        user_id = f"user_{request.client.host.replace('.', '_')}"

    conversation_id = configurable.get("conversation_id", "default")

    configurable["user_id"] = user_id
    configurable["conversation_id"] = conversation_id

    config["configurable"] = configurable
    return config


add_routes(
    app,
    chain_with_history,
    path="/chat",
    per_req_config_modifier=_per_request_config_modifier,
)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
 