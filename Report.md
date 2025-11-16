<div align="center">
<h2>Cloud Computing S1-25_CCZG527 Assignment 2</h2>
<br>
<h1>AWS Emulator on Bare-Metal Infrastructure: A FinOps-Driven Cloud Simulation Framework</h1>
</div>
<br>

## Group 12
Gautam Krishna MS [2025MT03133] <br>
Zainal Abdeen Hameed [2025MT03070]


-----

## Table of Contents

1.  Executive Summary
2.  Project Vision and Objectives
    2.1. Vision and Core Idea: The "Private Cloud Sandbox"
    2.2. Technical Objectives
    2.3. Technology Stack Overview
3.  Organizational and Strategic Relevance
    3.1. Cloud Cost Reduction and FinOps Alignment
    3.2. Training and Skill Development
    3.3. Enterprise IT and DevSecOps Enablement
4.  Detailed System Architecture
    4.1. Architectural Diagram and Data Flow
    4.2. Component Deep Dive: LocalStack Services
5.  Deployment and Operational Use
    5.1. Quick Start Workflow
    5.2. Monitoring and Extensions (Future Enhancements)
6.  Project Details (Placeholders)
7.  Conclusion
8.  References

-----

## 1\. Executive Summary

This report presents the **AWS Emulator on Bare-Metal Infrastructure**, a project designed to transform any on-premise or bare-metal server into a fully functional, zero-cost AWS-compatible development and testing environment. By leveraging **LocalStack**, **Docker Compose**, and **AWS Lambda container images** running a **FastAPI** microservice, the platform provides high-fidelity, offline emulation of core AWS services, including **API Gateway**, **Lambda**, **DynamoDB**, and **S3**.

The fundamental value proposition is to establish a **cost-free, high-fidelity cloud-native sandbox** for development, testing, and training. This solution directly addresses the rising imperative of **FinOps (Cloud Financial Operations)** by eliminating the variable costs associated with continuously running non-production cloud environments, which are a major source of cloud cost overrun. The resulting architecture offers a repeatable, disposable environment that mirrors real AWS behavior, significantly reducing the Total Cost of Ownership (TCO) for development and accelerating the development lifecycle.

-----

## 2\. Project Vision and Objectives

### 2.1. Vision and Core Idea: The "Private Cloud Sandbox"

The overarching vision is to establish a **"Private Cloud Sandbox"**—a complete, local cloud simulation environment that functions *inside the data center* or on a developer's machine. This isolated testbed mirrors AWS APIs and infrastructure behavior.

> 💡 **Core Idea (Motto):** "Run AWS inside your data center — without paying AWS." The ultimate goal is turning bare-metal infrastructure into a **cost-free, AWS-like environment** for development and education.
>
> *The Project's Philosophy:* <u>***"If the cloud is expensive, emulate it. If innovation is the goal, democratize it."***</u>

### 2.2. Technical Objectives

  * **High-Fidelity Emulation:** Achieve behavior parity with critical AWS APIs using LocalStack to ensure applications built and tested locally function as expected when deployed to the real AWS Cloud.
  * **Decoupled & Portable Architecture:** Utilize Docker Compose for orchestration to ensure the entire environment can be bootstrapped repeatably on any bare-metal host, embodying the principle of **Immutable Infrastructure**.
  * **Infrastructure as Code (IaC) Simulation:** Use the AWS CLI and Bash scripts to automate resource provisioning, mimicking real IaC tools like CloudFormation or Terraform in a local context.
  * **Modern Serverless Stack:** Demonstrate a production-like microservice architecture using **FastAPI** running on an emulated **AWS Lambda** compute layer.

### 2.3. Technology Stack Overview

The platform uses a layered approach, leveraging key components to simulate a production serverless microservice environment on a bare-metal host orchestrated by Docker Compose. The AWS emulation is primarily provided by the **LocalStack** framework.

| Layer | Technology | Description |
| :--- | :--- | :--- |
| **Orchestration** | Docker Compose | Bootstraps the entire multi-container environment on bare metal. |
| **Emulation Core** | LocalStack (including **Moto** Emulation Libraries) | Core framework providing high-fidelity, API-level emulation of AWS services. |
| **Emulated API** | LocalStack API Gateway | REST routing and integration simulation. |
| **Compute Runtime** | AWS Lambda (LocalStack) | Serverless function execution (runs the FastAPI container image). |
| **Data Persistence** | LocalStack DynamoDB + S3 | Emulated NoSQL database and object storage. |
| **Infrastructure Control** | AWS CLI + Shell Scripts | Automated provisioning of emulated resources. |

-----

## 3\. Organizational and Strategic Relevance

This project aligns with the industry's shift towards **FinOps, DevSecOps, and Cloud-Native Education**.

### 3.1. Cloud Cost Reduction and FinOps Alignment

This initiative embodies **FinOps principles**, driving financial accountability and maximizing business value from the cloud. It provides a direct mechanism to control the highly variable costs of non-production environments.

| FinOps Principle | How This Project Supports It | Sample Monthly Savings Estimate (for one small dev team) |
| :--- | :--- | :--- |
| **Inform** | Quantifies the cost of AWS Dev/Test environments vs. LocalStack equivalents. | **Visibility:** Avoids $150/month in idle EC2/RDS instances (e.g., t3.medium/db.t3.small). |
| **Optimize** | Redirects workloads to local emulation during non-production cycles. | **Optimization:** Eliminates 500 hours of billed Lambda executions (at $0.20/GB-hour) and API Gateway requests, saving approximately **$100/month\*\* on usage charges. |
| **Operate** | Enables teams to run predictable, zero-cost cloud workloads locally. | **TCO Reduction:** Saves **$50/month** by eliminating DynamoDB On-Demand charges and S3 storage for non-production assets. |
| **Total Estimated Savings (Monthly)** | **90–100% of non-production environment costs** | **~$300–$500/month** per team/project for typical non-production environments. |

### 3.2. Training and Skill Development

The emulator democratizes access to AWS concepts by creating a controlled, high-fidelity, and cost-free training environment.

  * **Risk-Free Lab Environment:** Teams can practice complex AWS workflows (API Gateway, Lambda, DynamoDB, S3) offline and risk-free, without requiring real cloud accounts, budgets, or complex IAM management.
  * **Corporate Upskilling:** Ideal for corporate upskilling and DevOps bootcamps, building real-world AWS experience and cloud-native concepts without accruing cloud bills.

### 3.3. Enterprise IT and DevSecOps Enablement

  * **Shift-Left Security and Testing:** Enables **Shift-Left Testing** by providing a realistic local emulation. Security flaws and misconfigurations are identified and fixed early, significantly reducing remediation costs.
  * **Supports Air-Gapped/Data Sovereignty:** Converts idle on-premise servers into self-hosted AWS emulators, supporting environments where strict security and **data sovereignty** require restricted internet access or reliance on public cloud credentials.
  * **Developer Productivity:** Improves feedback loops, allowing developers to prototype and debug locally with real AWS SDKs, thereby accelerating developer velocity.

-----

## 4\. Detailed System Architecture

### 4.1. Architectural Diagram and Data Flow

The architecture simulates a standard AWS serverless microservice pattern, with LocalStack serving as the API layer and the backing data stores.



### 4.2. Component Deep Dive: LocalStack Services

LocalStack supports a comprehensive and growing number of AWS services (over 70-100 services), providing developers with an extensive environment for local testing.

| Category | Emulated Services (Examples) | Project Utilization |
| :--- | :--- | :--- |
| **Compute** | Lambda, EC2, ECS/EKS, Elastic Beanstalk, Batch | **Lambda** (Container Image Runtime) |
| **Storage** | S3, EBS, EFS, Glacier, S3 Control | **S3** (Object Storage Emulation) |
| **Database** | DynamoDB, RDS, ElastiCache, Neptune, Redshift | **DynamoDB** (NoSQL Persistence) |
| **Networking** | API Gateway, Route 53, CloudFront, ELB/ALB | **API Gateway** (REST Routing) |
| **Messaging** | SQS, SNS, EventBridge, Step Functions | Future Enhancements |
| **Security** | IAM, KMS, Secrets Manager, Cognito, WAF | IAM (Mocked Roles for Permissions) |

-----

## 5\. Deployment and Operational Use

### 5.1. Quick Start Workflow

The deployment demonstrates the repeatability and automation benefits of IaC in a local context, using the dedicated `awslocal` wrapper to target the LocalStack edge port (`4566`).

1.  **Start Environment:** `docker compose up -d` is used to bootstrap all LocalStack services.
2.  **Resource Provisioning:** `./setup_localstack.sh` uses the `awslocal` CLI to provision emulated resources (DynamoDB tables and S3 buckets).
3.  **Code Deployment:** The Lambda container image is built and deployed using `./scripts/deploy_lambda_zip.sh`.
4.  **Service Integration:** API Gateway is configured with a proxy integration to the deployed Lambda function using `./scripts/setup_apigateway.sh`.

### 5.2. Monitoring and Extensions (Future Enhancements)

  * **Emulated Observability:** LocalStack provides emulation for **CloudWatch** logs and metrics, allowing developers to test monitoring and debugging processes within the isolated environment.
  * **Future Enhancements (Project Roadmap):** The platform is designed for extensibility, with future work planned to include:
      * Integration with declarative tools like **Terraform or CDK** for infrastructure management.
      * Extension of the serverless footprint to integrate **SQS, SNS, and EventBridge**.
      * The inclusion of **FinOps metrics dashboards** (e.g., Grafana + Prometheus) for enhanced cost visualization.

-----

## 6\. Project Details

| Detail | Value |
| :--- | :--- |
| **Author** | **Gautam Krishna MS [2025MT03133], Zainal Abdeen Hameed [2025MT03070]** |
| **Institution** | **BITS Pilani - Cloud Computing [S1-25_CCZG527]** |
| **Project Type** | **Assignment - 1** |
| **Date of Report** | **16 - 11 - 2025** |

-----

## 7\. Conclusion

This **AWS Emulator on Bare-Metal Infrastructure** project represents a best-practice strategy for modern cloud development in the context of cost consciousness and security. The architecture successfully offloads resource-intensive non-production workloads to a private, controlled environment, establishing a powerful and risk-free platform for building and mastering AWS architectures. The system is a strategic enabler for both enterprises and individuals, combining cost intelligence, cloud-native realism, and open innovation.

-----

## 8\. References

| Ref. | Source/Documentation | Description | URL |
| :--- | :--- | :--- | :--- |
| **1.** | LocalStack Documentation | Official guide for the core emulation platform. | [https://docs.localstack.cloud/](https://docs.localstack.cloud/) |
| **2.** | AWS CLI Documentation | Official documentation for the command-line interface used for provisioning. | [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/) |
| **3.** | Docker Documentation | Official documentation for the containerization technology used for orchestration. | [https://docs.docker.com/](https://docs.docker.com/) |
| **4.** | FastAPI Documentation | Official documentation for the Python framework used for the application logic. | [https://fastapi.tiangolo.com/](https://fastapi.tiangolo.com/) |
| **5.** | LocalStack GitHub Repository | The open-source repository for the emulation tool. | [https://github.com/localstack/localstack](https://github.com/localstack/localstack) |
| **6.** | AWS Cloud Development Kit (CDK) | Industry tool for Infrastructure as Code (IaC) deployment. | [https://aws.amazon.com/cdk/](https://aws.amazon.com/cdk/) |
| **7.** | FinOps Foundation | Resource for the FinOps framework principles and best practices. | [https://www.finops.org/](https://www.finops.org/) |
| **8.** | Cloud Native Computing Foundation (CNCF) | Industry resource for cloud-native trends and practices. | [https://cncf.io/](https://cncf.io/) |
| **9.** | AWS SDK for Python (Boto3) Documentation | Official documentation for the Python SDK used for service interaction. | [https://boto3.amazonaws.com/v1/documentation/api/latest/index.html](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) |