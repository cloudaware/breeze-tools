{{/*
Create the name of the service account to use
*/}}
{{- define "breeze-agent.serviceAccount" -}}
{{- if .Values.serviceAccount.create -}}
{{ default .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the cluster role to use
*/}}
{{- define "breeze-agent.clusterRole" -}}
{{- if .Values.clusterRole.create -}}
{{ default .Values.clusterRole.name }}
{{- else -}}
    {{ default "default" .Values.clusterRole.name }}
{{- end -}}
{{- end -}}
