// ============================================================
// Robô de verificação de taxas · Simulador Mude
// Roda automaticamente pelo GitHub Actions (segundas, 8h de MS).
// Busca as páginas listadas em data/taxas_referencia.json,
// extrai os percentuais encontrados e compara com a referência.
// Divergência => o workflow abre um alerta (Issue) no GitHub.
// ============================================================
import { readFileSync, writeFileSync } from 'node:fs';

const cfg = JSON.parse(readFileSync('data/taxas_referencia.json', 'utf8'));
const linhas = [];
let houveMudanca = false;

const pctRegex = /\b(\d{1,2},\d{1,2})\s?%/g;

for (const fonte of cfg.fontes) {
  let status = 'ok', encontrados = [];
  try {
    const resp = await fetch(fonte.url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; MudeImoveisBot/1.0)' },
      signal: AbortSignal.timeout(30000)
    });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const html = (await resp.text()).replace(/<[^>]+>/g, ' ');
    const set = new Set();
    for (const m of html.matchAll(pctRegex)) {
      const v = parseFloat(m[1].replace(',', '.'));
      if (v >= 3 && v <= 20) set.add(m[1]); // faixa plausível de juros imobiliários
    }
    encontrados = [...set].slice(0, 25);
    if (!encontrados.includes(fonte.referencia)) {
      status = 'MUDANCA';
      houveMudanca = true;
    }
  } catch (e) {
    status = 'erro: ' + e.message; // página fora do ar ou bloqueando robôs
  }
  linhas.push({ banco: fonte.banco, url: fonte.url, referencia: fonte.referencia, status, encontrados });
}

const data = new Date().toLocaleDateString('pt-BR', { timeZone: 'America/Campo_Grande' });
let md = `## Verificação de taxas · ${data}\n\n`;
md += houveMudanca
  ? `**ATENÇÃO: possível mudança de taxa detectada.** Confira os sites abaixo, atualize a Tabela de Taxas no painel administrativo do Simulador Mude e depois atualize o arquivo \`data/taxas_referencia.json\` para silenciar este alerta.\n\n`
  : `Nenhuma mudança detectada em relação aos valores de referência.\n\n`;
for (const l of linhas) {
  md += `### ${l.banco}\n- Página: ${l.url}\n- Valor de referência: ${l.referencia}%\n- Situação: **${l.status}**\n`;
  if (l.encontrados.length) md += `- Percentuais encontrados na página: ${l.encontrados.join('% · ')}%\n`;
  md += '\n';
}
md += `> Verificação automática e aproximada: os sites dos bancos mudam de formato e podem bloquear robôs. Em caso de dúvida, confirme no simulador oficial do banco.\n`;

writeFileSync('relatorio_taxas.md', md);
console.log(md);
console.log(houveMudanca ? '::warning::Possível mudança de taxas detectada' : 'Sem mudanças.');
writeFileSync(process.env.GITHUB_OUTPUT ?? '/dev/null', `mudanca=${houveMudanca}\n`, { flag: 'a' });
