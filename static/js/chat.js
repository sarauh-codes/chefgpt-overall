function openChat() {
  document.getElementById('chat-overlay').style.display = 'flex';
  document.getElementById('chat-bubble').style.display = 'none';
  document.getElementById('chat-input').focus();
}

function closeChat() {
  document.getElementById('chat-overlay').style.display = 'none';
  document.getElementById('chat-bubble').style.display = 'flex';
}

function sendChip(text) {
  document.getElementById('chat-input').value = text;
  sendFloatingMessage();
}

async function sendFloatingMessage() {
  const input = document.getElementById('chat-input');
  const messages = document.getElementById('chat-messages');
  const text = input.value.trim();
  if (!text) return;

  const userRow = document.createElement('div');
  userRow.style.cssText = 'display:flex;justify-content:flex-end;';
  const userBubble = document.createElement('div');
  userBubble.style.cssText = 'background:linear-gradient(135deg,#ff6b35,#f7931e);color:white;padding:10px 14px;border-radius:14px;border-bottom-right-radius:4px;font-size:13px;max-width:75%;';
  userBubble.textContent = text;
  userRow.appendChild(userBubble);
  messages.appendChild(userRow);

  input.value = '';
  input.disabled = true;
  messages.scrollTop = messages.scrollHeight;

  const typing = document.createElement('div');
  typing.id = 'typing';
  typing.style.cssText = 'color:#aaa;font-size:12px;font-style:italic;padding:4px 8px;';
  typing.textContent = '⏳ ChefGPT is thinking...';
  messages.appendChild(typing);
  messages.scrollTop = messages.scrollHeight;

  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text })
    });
    if (!res.ok) throw new Error();
    const data = await res.json();
    typing.remove();

    const aiRow = document.createElement('div');
    aiRow.style.cssText = 'display:flex;align-items:flex-end;gap:8px;';
    const icon = document.createElement('div');
    icon.style.cssText = 'width:26px;height:26px;background:linear-gradient(135deg,#ff6b35,#f7931e);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;flex-shrink:0;';
    icon.textContent = '🍳';
    const bubble = document.createElement('div');
    bubble.style.cssText = 'background:#f5f5f5;padding:10px 14px;border-radius:14px;border-bottom-left-radius:4px;font-size:13px;max-width:75%;color:#333;';
    bubble.textContent = data.reply;
    aiRow.appendChild(icon);
    aiRow.appendChild(bubble);
    messages.appendChild(aiRow);

  } catch {
    typing.remove();
    const aiRow = document.createElement('div');
    const bubble = document.createElement('div');
    bubble.style.cssText = 'background:#f5f5f5;padding:10px 14px;border-radius:14px;font-size:13px;color:#999;';
    bubble.textContent = 'Oops! Something went wrong 😅';
    aiRow.appendChild(bubble);
    messages.appendChild(aiRow);
  }

  input.disabled = false;
  input.focus();
  messages.scrollTop = messages.scrollHeight;
}