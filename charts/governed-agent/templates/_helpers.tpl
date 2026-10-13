{{- define "ga.fullname" -}}{{ .Release.Name }}{{- end -}}

{{- define "ga.labels" -}}
app.kubernetes.io/part-of: governed-agent
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "ga.selector" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}

{{/* Restricted pod security: non-root, no privilege escalation, no capabilities. */}}
{{- define "ga.podSecurity" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "ga.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .uid }}
capabilities:
  drop: [ALL]
{{- end -}}

{{- define "ga.pythonImage" -}}{{ .Values.image.python.repository }}:{{ .Values.image.python.tag }}{{- end -}}

{{/* DATABASE_URL is assembled from the CloudNativePG secret; $(VAR) expansion
     needs the referenced variables declared first. */}}
{{- define "ga.dbEnv" -}}
- name: DB_USER
  valueFrom: {secretKeyRef: {name: {{ .Values.database.secretName }}, key: username}}
- name: DB_PASSWORD
  valueFrom: {secretKeyRef: {name: {{ .Values.database.secretName }}, key: password}}
- name: DATABASE_URL
  value: "postgresql+asyncpg://$(DB_USER):$(DB_PASSWORD)@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.name }}"
{{- end -}}

{{- define "ga.otelEnv" -}}
{{- if .Values.otel.enabled }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.otel.endpoint | quote }}
{{- end }}
- name: LOG_LEVEL
  value: INFO
{{- end -}}
