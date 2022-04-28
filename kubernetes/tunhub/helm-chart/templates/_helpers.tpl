{{/*
Create the name of the service account to use
*/}}
{{- define "breeze-agent.clusterRoleName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{/*
Create the name of the service account to use
*/}}
{{- define "breeze-agent.clusterRoleName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
