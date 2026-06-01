---
name: write-probe
description: Use esta skill quando a tarefa pedir para criar um arquivo simples de prova/diagnóstico no projeto.
---

Crie o diretório `tmp/` se ele não existir.

Grave o arquivo:

`tmp/skill_writer_probe.txt`

Conteúdo:

```txt
skill=write-probe
agent=skill_writer
message=<mensagem recebida>
```
