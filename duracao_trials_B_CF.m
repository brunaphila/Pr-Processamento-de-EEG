%% duracoes_ProtB_CF.m
% Gera tabela com as DURACOES reais por trial:
%  - dur_estim_s = (col4 - col3) em segundos
%  - dur_exec_s  = (col5 - col4) em segundos
% Para IDs 26 (linha 7) e 33 (linha 8), reps 1..3, até 9 trials.

clear; clc;

prot_file = 'ProtB_CF_corrigido_IDs.mat';  % AJUSTE se estiver em outra pasta
IDs    = [26 33];
linhas = [ 7  8];
fmt_in = 'dd-MMM-yyyy HH:mm:ss';           % p/ datetime (MMM=mês, mm=minuto)

S = load(prot_file);
if ~isfield(S,'ProtB_CF'), error('ProtB_CF não encontrado em %s', prot_file); end
ProtB_CF = S.ProtB_CF;

to_datetime = @(x) local_to_datetime_any(x, fmt_in);

DurCF = table('Size',[0 8], ...
              'VariableTypes', {'double','double','double','datetime','datetime','datetime','double','double'}, ...
              'VariableNames', {'id','rep','trial','t3','t4','t5','dur_estim_s','dur_exec_s'});

for u = 1:numel(IDs)
    id  = IDs(u);
    lin = linhas(u);
    for rep = 1:3
        A = ProtB_CF{lin, rep};
        if ~(ismatrix(A) && size(A,2) >= 5)
            warning('ID%02d rep%d: matriz inválida (cols<5). Pulando.', id, rep);
            continue;
        end
        ntr = min(9, size(A,1));

        if iscell(A)
            t3 = arrayfun(@(r) to_datetime(A{r,3}), (1:ntr)');
            t4 = arrayfun(@(r) to_datetime(A{r,4}), (1:ntr)');
            t5 = arrayfun(@(r) to_datetime(A{r,5}), (1:ntr)');
        else
            t3 = datetime(A(1:ntr,3), 'ConvertFrom','datenum');
            t4 = datetime(A(1:ntr,4), 'ConvertFrom','datenum');
            t5 = datetime(A(1:ntr,5), 'ConvertFrom','datenum');
        end

        d_est = seconds(t4 - t3);
        d_exe = seconds(t5 - t4);

        T = table( repmat(id,ntr,1), repmat(rep,ntr,1), (1:ntr)', ...
                   t3, t4, t5, d_est, d_exe, ...
                   'VariableNames', DurCF.Properties.VariableNames);
        DurCF = [DurCF; T]; %#ok<AGROW>
    end
end

% Salvar
save('duracoes_ProtB_CF_ID26_33.mat', 'DurCF');
writetable(DurCF, 'duracoes_ProtB_CF_ID26_33.csv');
disp('Arquivos salvos: duracoes_ProtB_CF_ID26_33.mat e .csv');

% Pequeno sumário (ignorando NaT/NaN)
ve = DurCF.dur_estim_s; ve = ve(isfinite(ve));
vx = DurCF.dur_exec_s;  vx = vx(isfinite(vx));
if ~isempty(ve)
    fprintf('Estimulação (s): min=%.3f  med=%.3f  max=%.3f\n', min(ve), median(ve), max(ve));
end
if ~isempty(vx)
    fprintf('Execução    (s): min=%.3f  med=%.3f  max=%.3f\n', min(vx), median(vx), max(vx));
end

%% ---- helper: parser robusto ----
function dt = local_to_datetime_any(x, fmt_in_primary)
    if isa(x,'datetime'), dt = x; return; end
    if isnumeric(x) && isscalar(x) && isfinite(x)
        dt = datetime(x, 'ConvertFrom','datenum'); return;
    end
    if ischar(x) || isstring(x)
        s = strtrim(string(x)); if s=="", dt=NaT; return; end
        % número em string? (ex.: '737457.49' ou '7.374e+05')
        if all(ismember(char(s), ['0123456789eE+-.']))
            d = str2double(s);
            if isfinite(d), dt = datetime(d,'ConvertFrom','datenum'); return; end
        end
        try, dt = datetime(s,'InputFormat',fmt_in_primary,'Locale','en_US'); return; catch, end
        try, dt = datetime(s); return; catch, end
        dt = NaT; return;
    end
    dt = NaT;
end
