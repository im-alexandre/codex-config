# Migrated To pptx-utils

Esta skill foi desativada para evitar duas skills concorrentes para PPTX.

Use a skill global `pptx-utils`:

```powershell
C:\Users\imale\.codex\skills\pptx-utils\bin\pptx-utils\pptx-utils.exe --help
```

Os scripts Python uteis da skill antiga foram incorporados em:

```text
C:\Users\imale\.codex\skills\pptx-utils\scripts
```

O fluxo padrao agora prioriza edicao confiavel com .NET/Open XML. PptxGenJS fica apenas como fallback para decks novos do zero quando nao houver template existente.
