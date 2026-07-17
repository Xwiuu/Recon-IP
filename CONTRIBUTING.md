# 🤝 Contribuindo para o ReconIP

> **"A jornada de um MVP até um canivete suíço é feita de pequenas contribuições."**

---

## 🌟 Código de Conduta

Este projeto adota um [Código de Conduta](CODE_OF_CONDUCT.md). Ao participar, você concorda em manter um ambiente respeitoso e colaborativo.

---

## 🗺️ Roadmap & Issues

Antes de começar, veja se já existe uma [issue](https://github.com/Xwiuu/Recon-IP/issues) sobre o que você quer implementar. Issues estão categorizadas como:

| Label | Significado |
|-------|-------------|
| `bug` | Algo quebrado |
| `enhancement` | Nova funcionalidade |
| `good first issue` | Ideal para primeiro PR |
| `help wanted` | Precisa de ajuda |
| `documentation` | Melhoria em docs |

---

## 🧪 Setup do Ambiente

```bash
git clone https://github.com/Xwiuu/Recon-IP.git
cd Recon-IP
chmod +x reconip.sh super_recon.sh lib/*.sh
cp config.env.example config.env
# Edite config.env com suas chaves (opcional)
```

---

## 📏 Padrões de Código

### Shell Script

| Regra | Descrição |
|-------|-----------|
| **Shebang** | `#!/bin/bash` |
| **Estilo** | `snake_case` para funções e variáveis |
| **Indentação** | 4 espaços (sem tabs) |
| **Quoting** | Sempre usar `"$var"` (double quote) |
| **Bash** | Manter compatibilidade com Bash 4.0+ |
| **Erros** | Tratar com `||` ou `if $?; then` |
| **Debug** | Usar `log_debug` de `core.sh` |

### Estrutura de Módulo

```bash
#!/bin/bash
# nome_modulo.sh - Descrição curta

nome_da_funcao() {
    local param1=$1
    local param2=$2

    # Lógica aqui
    log_info "Executando..."

    if algum_comando; then
        log_success "OK"
    else
        log_warning "Fallback"
    fi
}
```

### Mensagens de Commit (Conventional Commits)

```
feat:     Nova funcionalidade
fix:      Correção de bug
docs:     Documentação
style:    Formatação, estilo
refactor: Refatoração de código
test:     Testes
chore:    Build, dependências, config
perf:     Performance
ci:       CI/CD
```

**Exemplos:**

```
feat: adiciona módulo de OSINT para Instagram
fix: corrige timeout no scan de portas UDP
docs: atualiza README com novos badges
refactor: extrai lógica de DNS para lib/dns.sh
```

---

## 🔄 Fluxo de Trabalho

```
1. 🍴 Faça um Fork do repositório
2. 🌿 Crie uma branch descritiva
3. 💻 Implemente sua modificação
4. ✅ Teste em diferentes ambientes (Linux, WSL, Git Bash)
5. 📝 Commit seguindo Conventional Commits
6. 📤 Push para seu fork
7. 🔀 Abra um Pull Request
```

### Nomenclatura de Branches

```
feature/nome-da-feature
fix/nome-do-bug
docs/melhoria-docs
refactor/o-que-foi-refatorado
```

---

## 🧪 Testes

Teste sua contribuição em **pelo menos 2** destes ambientes:

- Linux (Ubuntu/Debian)
- WSL (Windows)
- Git Bash (Windows)

```bash
# Teste básico
./reconip.sh -h
./super_recon.sh -h

# Teste de scan
./super_recon.sh -s 8.8.8.8

# Teste de todas as libs
for lib in lib/*.sh; do
    bash -n "$lib" || echo "ERRO em $lib"
done
```

---

## 📋 Checklist para Pull Request

- [ ] Código segue os padrões do projeto
- [ ] Testei em Linux e/ou Windows
- [ ] Não quebrei funcionalidades existentes
- [ ] Adicionei/atualizei documentação se necessário
- [ ] Verifiquei com `bash -n` se não há erros de sintaxe
- [ ] Commit messages seguem Conventional Commits

---

## 💬 Dúvidas?

Abra uma [discussion](https://github.com/Xwiuu/Recon-IP/discussions) ou issue.

---

## 🏆 Reconhecimento

Todo contribuidor que tiver um PR mergeado entra no **Hall da Fama** do README principal!

---

<div align="center">
  <strong>Obrigado por tornar o ReconIP ainda melhor!</strong>
  <br>
  <code>⭐ ⭐ ⭐ ⭐ ⭐</code>
</div>
