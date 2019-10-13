- apiVersion: image.openshift.io/v1
  kind: ImageStream
  metadata:
    annotations:
      openshift.io/generated-by: OpenShiftNewApp
    creationTimestamp: null
    labels:
      app: redis-fx
    name: redis-fx
  spec:
    lookupPolicy:
      local: false
  status:
    dockerImageRepository: ""
- apiVersion: build.openshift.io/v1
  kind: BuildConfig
  metadata:
    annotations:
      openshift.io/generated-by: OpenShiftNewApp
    creationTimestamp: null
    labels:
      app: redis-fx
    name: redis-fx
  spec:
    nodeSelector: null
    output:
      to:
        kind: ImageStreamTag
        name: redis-fx:latest
    postCommit: {}
    resources: {}
    source:
      contextDir: redis
      git:
        uri: https://github.com/andesm/fx-system-trade.git
      type: Git
    strategy:
      dockerStrategy:
        from:
          kind: ImageStreamTag
          name: redis5:latest
          namespace: openshift
      type: Docker
    triggers:
    - github:
        secret: GICb9IodagG1diaZLK8G
      type: GitHub
    - generic:
        secret: PgaFHrtgyO34wvvadxJP
      type: Generic
    - type: ConfigChange
    - imageChange: {}
      type: ImageChange
  status:
    lastVersion: 0
- apiVersion: apps.openshift.io/v1
  kind: DeploymentConfig
  metadata:
    annotations:
      openshift.io/generated-by: OpenShiftNewApp
    creationTimestamp: null
    labels:
      app: redis-fx
    name: redis-fx
  spec:
    replicas: 1
    selector:
      app: redis-fx
      deploymentconfig: redis-fx
    strategy:
      resources: {}
    template:
      metadata:
        annotations:
          openshift.io/generated-by: OpenShiftNewApp
        creationTimestamp: null
        labels:
          app: redis-fx
          deploymentconfig: redis-fx
      spec:
        containers:
        - image: redis-fx:latest
          name: redis-fx
          ports:
          - containerPort: 6379
            protocol: TCP
          resources: {}
          volumeMounts:
          - name: nfs-share
            mountPath: /data/db
            subPath: openshift/db/redis
          - name: redis-socket
            mountPath: /tmp/redis.sock
        volumes:
        - name: nfs-share
          persistentVolumeClaim:
            claimName: flg-pvc
        - name: redis-socket
          hostPath:
            path: /tmp/redis.sock
    test: false
    triggers:
    - type: ConfigChange
    - imageChangeParams:
        automatic: true
        containerNames:
        - redis-fx
        from:
          kind: ImageStreamTag
          name: redis-fx:latest
      type: ImageChange
  status:
    availableReplicas: 0
    latestVersion: 0
    observedGeneration: 0
    replicas: 0
    unavailableReplicas: 0
    updatedReplicas: 0
- apiVersion: v1
  kind: Service
  metadata:
    annotations:
      openshift.io/generated-by: OpenShiftNewApp
    creationTimestamp: null
    labels:
      app: redis-fx
    name: redis-fx
  spec:
    ports:
    - name: 6379-tcp
      nodePort: 30379
      port: 6379
      protocol: TCP
      targetPort: 6379
    selector:
      app: redis-fx
      deploymentconfig: redis-fx
    type: NodePort
  status:
    loadBalancer: {}
kind: List
metadata: {}
