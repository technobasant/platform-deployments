{{/* One Argo CD Application. Args: name, ns, wave, source (dict), ssa (bool), ignore (list). */}}
{{- define "root.app" -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: {{ .wave | quote }}
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .ns }}
  source: {{- toYaml .source | nindent 4 }}
  {{- with .ignore }}
  ignoreDifferences: {{- toYaml . | nindent 4 }}
  {{- end }}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    retry:
      limit: 10
      backoff: {duration: 10s, factor: 2, maxDuration: 3m}
    syncOptions:
      - CreateNamespace=true
      {{- if .ssa }}
      - ServerSideApply=true
      {{- end }}
{{- end -}}
