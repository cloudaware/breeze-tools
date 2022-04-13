{{/*
Create the name of the service account to use
*/}}
{{- define "breeze-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
