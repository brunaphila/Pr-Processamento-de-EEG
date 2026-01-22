# Pipeline de Pré-processamento e Análise Espectral (EEG)

Este repositório reúne os scripts utilizados no pipeline de processamento de EEG da Iniciação Científica, desde a conversão dos dados brutos do Open Ephys (`.continuous`) até a análise espectral via PSD (Welch).

A sequência abaixo reflete o fluxo real de preparação dos dados para análise, incluindo correções de protocolo, concatenação de cortes para viabilizar ICA, filtragens espaciais (CAR), filtragem temporal e cálculo de PSD.

---

## Visão geral:

1. **Conversão Open Ephys**: `.continuous` → `.mat` (registro inteiro por canal)
2. **Correção do Protocolo C**: padronização/correção da planilha/estrutura de protocolo usada como referência para cortes
3. **Concatenação de sinais após ICA (Prot. A e B)**: união dos 3 cortes (sinais grandes demais para ICA no formato completo)
4. **Filtragem espacial (CAR)**: CAR geral e CAR específico (C3, Cz, C4)
5. **Filtragem temporal pós-ICA**: passa-banda 2–50 Hz em lote
6. **Exportação para Python**: `.set` → `.mat` (dados + srate + chanlocs)
7. **PSD (Welch)**: cálculo da densidade espectral de potência e exportação final em `.mat`

---

## 1) Conversão `.continuous` → `.mat` (Open Ephys)

### Scripts
- `load_open_ephys_data_faster.m`
- `continuous_para_mat_arq_inteiro.m`

### O que essa etapa faz
Converte arquivos do Open Ephys (`100_CH1.continuous` … `100_CH32.continuous`) em um único arquivo `.mat` por voluntário, no formato **canais × amostras** (registro inteiro, sem cortes).  
A leitura dos `.continuous` é realizada pela função `load_open_ephys_data_faster.m` (utilizada como dependência no script principal de conversão).

**Saída típica:** `IDxx_<protocolo>.mat` contendo `data` (32 × N)

---

## 2) Correção do Protocolo C (referência para cortes)

### Arquivo de referência
- `ProtC_completo_CORRIGIDO.mat`

### O que essa etapa representa
O Protocolo C utiliza horários (início/fim) de cada trial para localizar trechos no EEG contínuo. Essa etapa corresponde à versão corrigida da referência do protocolo, usada pelo script de corte para garantir consistência nos intervalos recortados.

---

## 3a) Cortes do Protocolo C (segmentação por trial)

### Script
- `cortes_protC.m`

### O que essa etapa faz
Para cada voluntário, carrega o EEG contínuo (`data` 32×N) e recorta os trechos correspondentes aos trials do Protocolo C a partir da referência `ProtC_completo_CORRIGIDO.mat`.  
Gera cortes separados para:
- **Exploração** (18 trials)
- **Execução** (18 trials)

**Saída:** arquivos `.mat` por trial, organizados por pasta do voluntário (corte + metadados do trial).

## 3b) Cortes do Protocolo B (CF)

### Scripts
- `duracao_trials_B_CF.m`
- `cortes_manuais_protB_CF.m`

### O que essa etapa faz
O Protocolo B (CF) foi segmentado conforme os intervalos definidos no protocolo. Como os trials exigiam alinhamento manual do instante inicial (`t3`) e as durações variavam, o processo foi dividido em duas partes:

1) **Cálculo das durações reais (por trial)**
- `duracao_trials_B_CF.m` carrega `ProtB_CF_corrigido_IDs.mat` e calcula, para IDs 26 e 33 (reps 1..3, até 9 trials), as durações:
  - `dur_estim_s = t4 - t3`
  - `dur_exec_s  = t5 - t4`
- Salva a tabela `DurCF` em `duracoes_ProtB_CF_ID26_33.mat` e `.csv`.

2) **Cortes manuais usando `t3` + `DurCF`**
- `cortes_manuais_protB_CF.m` usa um plano manual de inícios `t3` (em segundos, relativo ao `.set`) e a tabela `DurCF` para calcular `t4` e `t5`.
- Gera dois segmentos por trial:
  - **ESTIM:** `t3..t4`
  - **EXEC:** `t4..t5`
- Salva:
  - `.mat` com `eeg_data` e `corte_struct`
  - `.set` “minimalista” (via `pop_importdata`)
- Organiza as saídas em `segments_IDxx_ProtB_CF_MANUAL`, com subpastas:
  - `cortes_estim_IDxx_rep#_MANUAL`
  - `cortes_exec_IDxx_rep#_MANUAL`

---

## 4) Concatenação dos 3 cortes (Prot. A e B) para viabilizar ICA

### Script
- `concatenação_3_sinais.m`

### Motivação
Os sinais completos eram grandes demais para execução do ICA diretamente. Por isso, foram gerados **3 cortes** e, após a etapa de ICA, esses cortes foram **concatenados** no tempo para reconstruir um sinal contínuo (por canal) mantendo a sequência analisada.

### O que essa etapa faz
Carrega 3 datasets (`.set`) e concatena os sinais no eixo do tempo, resultando em um único `.set` final concatenado.

**Saída:** um `.set` concatenado por voluntário.

---

## 5) Filtragem espacial (CAR)

### Scripts
- `filtro_espacial_CAR_especifico.m`
- `filtro_espacial_CAR_geral.m`

### O que essa etapa faz
Aplicação do **Common Average Reference (CAR)** em lote sobre arquivos `.set` (EEGLAB):

- **CAR específico (`filtro_CAR_especifico.m`)**: calcula a média instantânea de **C3, Cz e C4** e subtrai essa média apenas desses canais.
- **CAR geral (`filtro_CAR_geral.m`)**: calcula a média instantânea entre **todos os canais** (`mean(EEG.data,1)`) e subtrai de cada canal.

**Saída:** novos `.set` com sufixos indicando o tipo de CAR aplicado.

---

## 6) Filtragem temporal pós-ICA (2–50 Hz)

### Script
- `filtro_temporal_2-50Hz.m`

### O que essa etapa faz
Filtra em lote os arquivos `.set` (pós-ICA), aplicando um filtro **passa-banda IIR de 2 a 50 Hz** (ordem 8), canal por canal, usando a taxa de amostragem (`EEG.srate`).

**Saída:** arquivos `.set` com sufixo `_filtrado.set`.

---

## 7) Exportação do EEGLAB para `.mat` (para uso no Python)

### Script
- `set_para_mat.m`

### O que essa etapa faz
Converte datasets do EEGLAB (`.set` + `.fdt`) para `.mat` contendo:
- `eeg_data` (canais × amostras)
- `srate`
- `chanlocs`

Essa estrutura foi utilizada como entrada direta para a análise de PSD em Python.

---

## 8) PSD (Welch) — etapa final

### Script
- `psd_arq_mat.py`

### O que essa etapa faz
Lê os `.mat` exportados do EEGLAB e calcula a **PSD por Welch** para cada canal:
- Janela **Hamming**
- `nperseg = 2*srate` (janela de 2 segundos)
- `noverlap = 50%`

**Saída final:** arquivos `*_psd.mat` contendo:
- `freqs` (frequências)
- `psds` (PSD por canal)
- `srate`
- `chan_labels`

---

## Requisitos

### MATLAB
- MATLAB
- EEGLAB instalado e acessível no path (para leitura/salvamento de `.set`)

### Python
- `numpy`
- `scipy`
- `tqdm` (se estiver usando barra de progresso)

---

## Ordem recomendada de execução (resumo)

1. `continuous_para_mat_arq_inteiro.m` (usa `load_open_ephys_data_faster.m`)
2. (Protocolo C) usar `ProtC_completo_CORRIGIDO.mat`
3. `cortes_ProtC.m`
4. (Prot. A/B) `concatenação_3_sinais.m` (quando aplicável)
5. `filtro_CAR_especifico.m` e/ou `filtro_CAR_geral.m`
6. `filtro_pos_ICA_2_50_todos_os_arquivos.m`
7. `set_para_mat.m`
8. `PSD_arq_mat.py`

---

