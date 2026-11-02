FROM ghcr.io/uaiso-serious/scm-runtime:latest

# claude-runtime: Claude Code + plugin oficial langfuse-observability sobre a base SCM.
# O ENTRYPOINT da base é mantido; só o CMD muda.
COPY --chown=agent:agent rootfs/usr/local/share/claude-runtime/20-claude.toml /home/agent/.config/mise/conf.d/20-claude.toml
RUN mise install && mise reshim

# plugin instalado no build; as chaves LANGFUSE_* vêm do env em runtime
# o marketplace só aceita branch/tag, então clona no SHA fixo e adiciona via path local
ARG LANGFUSE_PLUGIN_SHA=b5b7cc364996467e856dc17575b5674f4799ad87
RUN git clone https://github.com/langfuse/Claude-Observability-Plugin.git ~/langfuse-plugin \
 && git -C ~/langfuse-plugin checkout "$LANGFUSE_PLUGIN_SHA" \
 && claude plugin marketplace add ~/langfuse-plugin \
 && claude plugin install langfuse-observability@langfuse-observability

# aquece o cache do uv (deps do hook) para o primeiro Stop não depender de rede
RUN uv run --quiet --script "$(ls -d ~/.claude/plugins/cache/*/*/*)/hooks/langfuse_hook.py" </dev/null || true

USER root
COPY rootfs/usr/local/bin/ /usr/local/bin/
USER agent

# SHA do commit do build (docker build --build-arg GIT_SHA=$(git rev-parse --short HEAD)); vira a tag image: no Langfuse
ARG GIT_SHA=unknown
ENV RUNNER_IMAGE_SHA=$GIT_SHA

RUN echo '{"hasCompletedOnboarding": true, "projects": {"/workspace": {"hasTrustDialogAccepted": true}}}' > ~/.claude.json \
 && mkdir -p ~/.claude

CMD ["claude-start.sh"]
