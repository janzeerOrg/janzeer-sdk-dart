(Adicione a seguinte linha à tabela existente)

| Program | What it shows |
|---|---|
| [`offline_sign_and_broadcast.dart`](offline_sign_and_broadcast.dart) | Three-step flow: read nonce/network, sign offline, broadcast later. |

(Atualize a contagem no topo do arquivo)
Seven small programs, each a complete flow against a running node. Point them at a network with
`JANZEER_NODE_URL` (default `http://localhost:7019`); `sdk_conformance/e2e/node-up.sh` starts a local one with a
funded wallet, and `tool/run_examples.sh` runs all seven.
