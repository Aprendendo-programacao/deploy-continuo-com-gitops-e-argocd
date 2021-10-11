# Deploy Contínuo com GitOps e ArgoCD

### Requisitos

* [Docker](https://www.docker.com/)

* [Kind](https://kind.sigs.k8s.io/)

### Criação do cluster Kubernetes

* `$ kind create cluster --name argocd`

* Verificar se o cluster foi criado com sucesso

  * `$ kubectl get nodes`

### Criar um *Web Server* em Go

```go
package main

import "net/http"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("<h1>Hello World</h1>"))
	})
	http.ListenAndServe(":8080", nil)
}
```

### Containerização da aplicação

* **Dockerfile**

  ```dockerfile
  FROM golang:1.17 AS builder

  WORKDIR /app
  COPY . .
  RUN CGO_ENABLED=0 go build -o server main.go # compilar o arquivo "main.go" em um arquivo executável chamado "server" (flag -o)

  FROM alpine:3.12

  WORKDIR /app
  COPY --from=builder /app/server .
  CMD ["./server"] # Executar o Web Server quando o container subir
  ```

* **Criação da imagem com a TAG latest**

  * `$ docker build -t imgabreuw/deploy-continuo-com-gitops-e-argocd:latest .`

* **Enviar a imagem para o Docker Hub**

  * Fazer o login: `$ docker login`

  * Enviar a imagem com a TAG latest: `$ docker push imgabreuw/deploy-continuo-com-gitops-e-argocd:latest`

* **Rodar a aplicação a partir da imagem enviada ao Docker Hub**

  * `$ docker run --rm -p 8080:8080 imgabreuw/deploy-continuo-com-gitops-e-argocd:latest`

### Deploy da aplicação no Kubernetes (K8S)

* **Objetos necessários para o o deploy**

  * Deployment

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: goapp
    spec:
      replicas: 5
      # Indicar quais aplicações serão gerenciadas por esse Deployment (no caso, todas as aplicações com "app=goapp")
      selector:
        matchLabels:
          app: goapp
      # Definição dos pods
      template:
        metadata:
          labels:
            app: goapp  
        spec:
          containers:
          - name: goapp 
            image: goapp # o Kustomize irá setar a versão da imagem automaticamente
            ports:
            - containerPort: 8080
    ```

    * Aplicar essa nova configuração no cluster Kubernetes

      * `$ kubectl apply -f k8s/deployment.yaml`

  * Service

    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: goapp
    spec:
      # Indicar quais aplicações serão gerenciadas por esse Service
      selector:
        app: goapp
      # Binding de portas
      ports:
      - port: 8080 # porta do Service
        targetPort: 8080 # porta do container
    ```

    > OBS: como tem mais de 1 réplica, o Service fará o balanceamento de carga entre os pods

    * Aplicar essa nova configuração no cluster Kubernetes

      * `$ kubectl apply -f k8s/service.yaml`

    * Binding de portas entre máquina local e o Service

      * `$ kubectl port-forward svc/goapp 8080:8080`

        > Fluxo de redirecionamento: maquina local (8080) > Service (8080) > Pod (Service é responsável por escolher a porta do melhor Pod)

* [Kustomize](https://kustomize.io/)

  * Instalação do Kustomize

    * `$ curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && sudo mv kustomize /usr/local/bin`

  * Função: fazer a troca de versão da imagem de forma automática e aplicar as alterações, automaticamente, das configurações no cluster Kubernetes

  * Arquivo de configuração

    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
    - deployment.yaml
    - service.yaml

    namespace: goapp

    images:
      - name: goapp
        newName: goapp
        newTag: v1
    ```

    * Aplicar as configurações no cluster Kubernetes

      * `$ kustomize build k8s`