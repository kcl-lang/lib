import { expect, test } from "@jest/globals";
import { load, invokeKCLRun } from "../src";

test("run", async () => {
  const inst = await load();
  const result = invokeKCLRun(inst, {
    filename: "test.k",
    source: `
schema Person:
  name: str

p = Person {name = "Alice"}`,
  });
  expect(result).toBe("p:\n  name: Alice");
});

export const SNIPPETS = [
  {
    label: "Kubernetes",
    value: `apiVersion = "apps/v1"
kind = "Deployment"
metadata = {
    name = "nginx"
    labels.app = "nginx"
}
spec = {
    replicas = 3
    selector.matchLabels = metadata.labels
    template.metadata.labels = metadata.labels
    template.spec.containers = [
        {
            name = metadata.name
            image = "nginx:1.14.2"
            ports = [{ containerPort = 80 }]
        }
    ]
}
`,
  },
  {
    label: "Abstraction",
    value: `import manifests

schema App:
    """The application model."""
    name: str
    replicas: int = 1
    labels?: {str:str} = {app = name}
    service?: Service
    containers?: {str:Container}

schema Service:
    """The service model."""
    $type?: str
    ports: [Port]

schema Port:
    """The port model."""
    port: int
    protocol: "TCP" | "UDP" | "SCTP" = "TCP"
    targetPort?: int | str

schema Container:
    """The container model."""
    image: str
    command?: [str]
    args?: [str]
    env?: [Env]
    volumes?: [Volume]
    resources?: Resource
    ports: [ContainerPort]

schema ContainerPort:
    """The container port model."""
    name?: str
    protocol: "TCP" | "UDP" | "SCTP" = "TCP"
    containerPort: int

    check:
        1 <= containerPort <= 65535, "containerPort must be between 1 and 65535, inclusive"

schema Env:
    name: str
    value: str

schema Volume:
    source: str
    path: str
    target: str
    readOnly?: bool = False

schema Resource:
    limits?: {str:}
    requests?: {str:}

kubernetesRender = lambda a: App {
    # Construct the deployment manifest.
    deployment = {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata.name = a.name
        metadata.labels = a.labels
        spec = {
            replicas = a.replicas
            selector.matchLabels = a.labels
            template.metadata.labels = a.labels
            template.spec.containers = [{
                name = name
                image = c.image
                command = c.command
                args = c.args
                env = c.env
                volumeMounts = c.volumes
                resources: c.resources
                ports = c.ports
            } for name, c in a.containers]
        }
    }
    # Construct the service manifest.
    service = {
        apiVersion = "v1"
        kind = "Service"
        metadata.name = a.name
        metadata.labels = a.labels
        spec = {
            type = a.service?.$type
            selector = a.labels
            ports = a.service?.ports
        }
    }
    # Returns Kubernetes manifests
    [
        deployment
        if a.service:
            service
        
    ]
}

app = App {
    name = "app"
    containers.nginx = {
        image = "nginx"
        ports = [{containerPort = 80}]
    }
    service.ports = [{port = 80}]
}

manifests.yaml_stream(sum([kubernetesRender(a) for a in App.instances()], []))
`,
  },
  {
    label: "Mutation",
    value: `import yaml

resource = yaml.decode("""\
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
""")

set_replicas = lambda item: {str:}, replicas: int {
    item | {
        if item?.kind == "Deployment":
            spec.replicas = replicas
        
    }
}

new_resource = set_replicas(resource, 5)
`,
  },
  {
    label: "Validation",
    value: `import yaml
import json

schema Server:
    ports: [int]

    check:
        all p in ports {
            0 < p < 65535
        }

server1: Server = yaml.decode("""\
ports:
- 80
- 8080
""")
server2: Server = json.decode("""\
{
    "ports": [80, 8000]
}
""")
`,
  },
  {
    label: "Computing integers",
    value: `x = (10 + 2) * 30 + 5
`,
  },
  {
    label: "Debugging values",
    value: `print("Output values")
`,
  },
  {
    label: "Conditionals",
    value: `if True:
    print("Hello")
else:
    print("unreachable")
`,
  },
  {
    label: "List",
    value: `data = ["one", "two", "three"]`,
  },
  {
    label: "Dict",
    value: `Config = {
    key = "value"    
}`,
  },
  {
    label: "Schema",
    value: `schema Nginx:
    """Schema for Nginx configuration files"""
    http: Http

schema Http:
    server: Server

schema Server:
    listen: int | str    # The attribute listen can be int type or a string type.
    location?: Location  # Optional, but must be non-empty when specified

schema Location:
    root: str
    index: str

nginx = Nginx {
    http.server = {
        listen = 80
        location = {
            root = "/var/www/html"
            index = "index.html"
        }
    }
}`,
  },
];

test("run example tests", async () => {
  const inst = await load();
  SNIPPETS.forEach((snippet) => {
    const result = invokeKCLRun(inst, {
      filename: "test.k",
      source: snippet.value,
    });
    expect(result).not.toContain("ERROR:");
  });
});
