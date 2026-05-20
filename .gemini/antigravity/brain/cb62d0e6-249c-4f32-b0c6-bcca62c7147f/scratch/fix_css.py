import os

path = r'c:\Users\azree\chefgpt-overall\static\css\dashboard.css'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = """.pan-loader .loader-food {
  width: 20%;
  height: 20%;
  background: var(--brand);
  position: absolute;
  bottom: 45%;
  left: 35%;
  border-radius: 50%;
  animation: flip-food 2s infinite ease-in-out;
}"""

new_block = """.pan-loader .loader-food {
  width: 40px;
  height: 40px;
  background: none;
  position: absolute;
  bottom: 45%;
  left: 35%;
  border-radius: 50%;
  animation: flip-food 2s infinite ease-in-out;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32px;
}

.pan-loader .loader-food::after {
  content: '🥦';
  animation: ingredient-cycle 2s infinite steps(1);
}

@keyframes ingredient-cycle {
  0% { content: '🥩'; }
  25% { content: '🥦'; }
  50% { content: '🥕'; }
  75% { content: '🥚'; }
  100% { content: '🍗'; }
}"""

# Try both \n and \r\n
if old_block in content:
    content = content.replace(old_block, new_block)
elif old_block.replace('\n', '\r\n') in content:
    content = content.replace(old_block.replace('\n', '\r\n'), new_block.replace('\n', '\r\n'))
else:
    # Fallback to a more flexible match
    import re
    pattern = re.compile(r'\.pan-loader \.loader-food \{[^\}]+\}', re.MULTILINE | re.DOTALL)
    content = pattern.sub(new_block, content, count=1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")
