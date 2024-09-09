use crate::{FmtOptions, KCLModule, RunOptions};
use anyhow::Result;

const WASM_PATH: &str = "../../kcl.wasm";
const BENCH_COUNT: usize = 20;
const SOURCES: &[&str] = &[
    r#"apiVersion = "apps/v1"
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
}"#,
    r#"import manifests

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

manifests.yaml_stream(sum([kubernetesRender(a) for a in App.instances()], []))"#,
    r#"import yaml

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

new_resource = set_replicas(resource, 5)"#,
    r#"import yaml
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
""")"#,
    r#"x = (10 + 2) * 30 + 5"#,
    r#"print("Output values")"#,
    r#"if True:
    print("Hello")
else:
    print("unreachable")"#,
    r#"data = ["one", "two", "three"]"#,
    r#"Config = {
    key = "value"    
}"#,
];

#[test]
fn test_run() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = 1".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    for _ in 0..BENCH_COUNT {
        let result = module.run(&opts)?;
        println!("{}", result);
    }
    Ok(())
}

#[test]
fn test_run_examples() -> Result<()> {
    for source in SOURCES {
        let opts = RunOptions {
            filename: "test.k".to_string(),
            source: source.to_string(),
        };
        let mut module = KCLModule::from_path(WASM_PATH)?;
        let result = module.run(&opts)?;
        assert!(!result.starts_with("ERROR:"), "source: {source}. result: {result}");
    }
    Ok(())
}

#[test]
fn test_run_parse_error() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = ".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}

#[test]
fn test_run_type_error() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a: str = 1".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}

#[test]
fn test_run_runtime_error() -> Result<()> {
    let opts = RunOptions {
        filename: "test.k".to_string(),
        source: "a = [][0]".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    let result = module.run(&opts)?;
    println!("{}", result);
    Ok(())
}

#[test]
fn test_fmt() -> Result<()> {
    let opts = FmtOptions {
        source: "a = 1".to_string(),
    };
    let mut module = KCLModule::from_path(WASM_PATH)?;
    for _ in 0..BENCH_COUNT {
        let result = module.fmt(&opts)?;
        println!("{}", result);
    }
    Ok(())
}
