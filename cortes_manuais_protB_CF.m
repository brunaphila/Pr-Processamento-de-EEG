%% cortes_ProtB_CF_MANUAL.m
% Corta segmentos MANUAIS usando durações reais (DurCF):
%   - Para cada ID/rep, você define t3_manual (9 valores em segundos, relativos ao .set carregado)
%   - O script usa DurCF para somar dur_estim_s e dur_exec_s e salvar ESTIM e EXEC.

clear; clc;

%% === Caminhos (AJUSTE AQUI) ===
base_dir_set_CF = 'C:\Users\Bruna\Documents\IC\Dados\Protocolo B\Com feedback vibrotátil';
dur_file        = 'duracoes_ProtB_CF_ID26_33.mat';    % gerado no script 1

%% === Carrega durações ===
S = load(dur_file);
DurCF = S.DurCF;

%% === Parâmetros ===
IDs           = [26 33];
linhas        = [ 7  8];   %#ok<NASGU> % (só informativo aqui)
Fs_overwrite  = [];        % deixe [] para usar Fs do .set; ou defina, ex.: 1000
clip_to_end   = true;      % se a janela passar do fim, corta até o fim em vez de pular
ntr_expected  = 9;

%% === PLANO MANUAL: começos t3 (s) dentro do .set ===
% Preencha 9 valores por rep (use NaN para pular aquele trial).
% Exemplo abaixo: primeiros 4 alinhados ao que já cortou; 5..9 reposicionados dentro do .set.
starts = struct();

% -------- ID26 --------
starts.ID26.rep1 = [ ...
     0, 148, 282, 416, ... % 1..4 (sugestão: iguais aos que já cortou)
    10,  55, 100, 140, 180 ... % 5..9: EXEMPLOS (EDITE!)
]';

starts.ID26.rep2 = [ ...
     0, 136, 270, 405, ...
    12,  58, 102, 145, 190 ...
]';

starts.ID26.rep3 = [ ...
     0, 135, 269, 403, ...
    15,  60, 105, 150, 195 ...
]';

% -------- ID33 --------
starts.ID33.rep1 = [ ...
     0, 136, 271, 405, ...
    20,  65, 110, 155, 200 ...
]';

starts.ID33.rep2 = [ ...
     0, 135, 269, 403, ...
    22,  67, 112, 157, 202 ...
]';

starts.ID33.rep3 = [ ...
     0, 135, 269, 403, ...
    25,  70, 115, 160, 205 ...
]';

% Observação:
% - Garanta que t3 + dur_estim_s + dur_exec_s caibam no .set;
% - Se não couber e clip_to_end==true, o segmento será cortado até o fim do arquivo.

%% === Execução dos cortes ===
for id = IDs
    out_root = fullfile(base_dir_set_CF, sprintf('segments_ID%02d_ProtB_CF_MANUAL', id));
    if ~exist(out_root,'dir'), mkdir(out_root); end

    for rep = 1:3
        % localizar dataset (por rep se existir; senão, único)
        [setname, per_rep] = find_set_file_rep(base_dir_set_CF, id, rep);
        EEG = pop_loadset('filename', setname, 'filepath', base_dir_set_CF);
        EEG = eeg_checkset(EEG);
        Fs  = EEG.srate;
        if ~isempty(Fs_overwrite), Fs = Fs_overwrite; end
        data = EEG.data;
        N    = size(data,2);
        tempo_eeg = (0:N-1)/Fs;

        key_id  = sprintf('ID%02d', id);
        key_rep = sprintf('rep%d', rep);
        if ~isfield(starts, key_id) || ~isfield(starts.(key_id), key_rep)
            warning('Sem plano manual para %s.%s; pulando.', key_id, key_rep);
            continue;
        end
        t3m = starts.(key_id).(key_rep);
        if numel(t3m) < ntr_expected
            warning('%s.%s tem %d começos; esperado %d. Completando com NaN.', key_id, key_rep, numel(t3m), ntr_expected);
            t3m(end+1:ntr_expected,1) = NaN;
        end

        % durações dessa combinação ID/rep
        mask = DurCF.id==id & DurCF.rep==rep;
        D = DurCF(mask, :);
        if height(D) < ntr_expected
            % completa com NaN se necessário
            falta = ntr_expected - height(D);
            D = [D; table( repmat(id,falta,1), repmat(rep,falta,1), (height(D)+1:ntr_expected)', ...
                           repmat(NaT,falta,1), repmat(NaT,falta,1), repmat(NaT,falta,1), ...
                           nan(falta,1), nan(falta,1), ...
                           'VariableNames', D.Properties.VariableNames)]; %#ok<AGROW>
        end

        out_est = fullfile(out_root, sprintf('cortes_estim_ID%02d_rep%d_MANUAL', id, rep));
        out_exe = fullfile(out_root, sprintf('cortes_exec_ID%02d_rep%d_MANUAL',  id, rep));
        if ~exist(out_est,'dir'), mkdir(out_est); end
        if ~exist(out_exe,'dir'), mkdir(out_exe); end

        for tr = 1:ntr_expected
            t3 = t3m(tr);
            if ~isfinite(t3), fprintf('ID%02d rep%d tr%02d: sem t3 manual (NaN). Pulando.\n', id, rep, tr); continue; end

            de = D.dur_estim_s(tr); dx = D.dur_exec_s(tr);
            if ~isfinite(de) || ~isfinite(dx)
                fprintf('ID%02d rep%d tr%02d: durações ausentes (estim=%.3f, exec=%.3f). Pulando.\n', id, rep, tr, de, dx);
                continue;
            end

            % janelas a partir de t3 manual
            t4 = t3 + de;
            t5 = t4 + dx;

            % --- ESTIM (t3..t4)
            [ok1, s1a, s1b] = save_segment(data, tempo_eeg, Fs, N, t3, t4, clip_to_end, ...
                out_est, sprintf('EEGestim_ID%02d_rep%d_trial%02d_MANUAL', id, rep, tr), ...
                out_root, sprintf('ID%02d_ProtB_CF_rep%d_trial%02d_estim_MANUAL', id, rep, tr));
            if ok1
                fprintf('ID%02d rep%d tr%02d: ESTIM OK [%d..%d] (%.3f s)\n', id, rep, tr, s1a, s1b, (s1b-s1a+1)/Fs);
            else
                fprintf('ID%02d rep%d tr%02d: ESTIM falhou (fora do arquivo?)\n', id, rep, tr);
            end

            % --- EXEC (t4..t5)
            [ok2, s2a, s2b] = save_segment(data, tempo_eeg, Fs, N, t4, t5, clip_to_end, ...
                out_exe, sprintf('EEGexec_ID%02d_rep%d_trial%02d_MANUAL', id, rep, tr), ...
                out_root, sprintf('ID%02d_ProtB_CF_rep%d_trial%02d_exec_MANUAL', id, rep, tr));
            if ok2
                fprintf('ID%02d rep%d tr%02d: EXEC  OK [%d..%d] (%.3f s)\n', id, rep, tr, s2a, s2b, (s2b-s2a+1)/Fs);
            else
                fprintf('ID%02d rep%d tr%02d: EXEC  falhou (fora do arquivo?)\n', id, rep, tr);
            end
        end
    end
end

disp('>>> Cortes MANUAIS (ProtB_CF) concluídos.');

%% --------- helpers ---------
function [ok, s_ini, s_fim] = save_segment(data, tempo_eeg, Fs, N, t_ini, t_fim, clip_to_end, out_dir_mat, base_name_mat, out_dir_set, setname)
    ok = 0; s_ini = NaN; s_fim = NaN;
    if ~isfinite(t_ini) || ~isfinite(t_fim) || t_fim <= t_ini
        return;
    end
    s1 = floor(t_ini*Fs) + 1;
    s2 = ceil(t_fim*Fs);
    if s1 > N, return; end
    if s2 < 1, return; end
    s1 = max(1, s1);
    if s2 > N
        if clip_to_end
            s2 = N;
        else
            return;
        end
    end
    if s2 <= s1, return; end

    X  = data(:, s1:s2);
    tt = tempo_eeg(s1:s2);

    % salva .mat
    eeg_data = X; %#ok<NASGU>
    corte_struct.corte = X;
    corte_struct.tempo = tt;
    corte_struct.tempo_inicio = t_ini;
    corte_struct.tempo_fim    = t_fim;
    corte_struct.s_start = s1;
    corte_struct.s_end   = s2;

    if ~exist(out_dir_mat,'dir'), mkdir(out_dir_mat); end
    save(fullfile(out_dir_mat, [base_name_mat '.mat']), 'eeg_data', 'corte_struct', '-v7.3');

    % salva .set minimalista
    EEGtmp = pop_importdata('data', X, 'nbchan', size(X,1), 'srate', Fs);
    EEGtmp = eeg_checkset(EEGtmp);
    if ~exist(out_dir_set,'dir'), mkdir(out_dir_set); end
    EEGtmp.setname = setname;
    pop_saveset(EEGtmp, 'filename', [setname '.set'], 'filepath', out_dir_set);

    ok = 1; s_ini = s1; s_fim = s2;
end

function [setname, per_rep] = find_set_file_rep(basedir, id, rep)
    pats_rep = { ...
        sprintf('ID%02d_B_CF_rep%d_eeglab.set', id, rep), ...
        sprintf('ID%02d_CF_rep%d_eeglab.set',    id, rep), ...
        sprintf('ID%02d_rep%d_eeglab.set',       id, rep)  ...
    };
    for p = pats_rep
        f = fullfile(basedir, p{1});
        if exist(f,'file'), setname = p{1}; per_rep = true; return; end
    end
    per_rep = false;
    setname = find_set_file(basedir, id);
end

function setname = find_set_file(basedir, id)
    pats = {sprintf('ID%02d_B_CF_eeglab.set',id), sprintf('ID%02d_CF_eeglab.set',id), ...
            sprintf('ID%02d_B_eeglab.set',id),   sprintf('ID%02d_eeglab.set',id)};
    for p = pats
        f = fullfile(basedir, p{1}); if exist(f,'file'), setname = p{1}; return; end
    end
    L = dir(fullfile(basedir, sprintf('ID%02d*.set', id)));
    if ~isempty(L), setname = L(1).name; return; end
    error('Não encontrei .set para ID%02d em %s', id, basedir);
end
