function sendChip(text) {
  document.getElementById('chat-input').value = text;
  sendMessage();
}

async function sendMessage() {
  const input = document.getElementById('chat-input');
  const messages = document.getElementById('chat-messages');
  const text = input.value.trim();
  if (!text) return;

  messages.innerHTML += `
    <div class="bubble-row user">
      <div class="bubble user">${text}</div>
    </div>`;
  input.value = '';
  messages.scrollTop = messages.scrollHeight;

  messages.innerHTML += `<div id="typing" class="typing">⏳ ChefGPT is thinking...</div>`;
  messages.scrollTop = messages.scrollHeight;

  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({message: text})
  });
  const data = await res.json();

  document.getElementById('typing')?.remove();
  messages.innerHTML += `
    <div class="bubble-row">
      <div class="ai-icon">🍳</div>
      <div class="bubble ai">${data.reply}</div>
    </div>`;
  messages.scrollTop = messages.scrollHeight;
}