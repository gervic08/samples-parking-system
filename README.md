# Payment & Authentication API Sample

This repository showcases selected backend components from a production-grade Ruby on Rails project. The code demonstrates best practices in service-oriented architecture, secure authentication, and robust payment processing.

## Features

- **Service Objects & Design Patterns:**  
  Decoupled business logic using service templates and payment strategy patterns.

- **Secure Authentication:**  
  JWT-based authentication with refresh tokens and token blacklisting for secure logout.

- **Robust Error Handling:**  
  Transactional operations, custom error classes, and integration with Sentry for error reporting.

- **Comprehensive Testing:**  
  RSpec unit and integration tests for critical payment flows.

- **RESTful API & Modular Routing:**  
  Well-organized routes and controllers following REST principles.

## Included Files

- `app/services/payments/process_successful_payment.rb`  
  Handles post-payment business logic for different payable types.

- `app/services/payments/strategies/wallet_payment.rb`  
  Implements wallet payment strategy.

- `spec/services/payments/strategies/wallet_payment_spec.rb`  
  RSpec tests for wallet payment processing.

- `app/models/wallet.rb`

- `app/controllers/api/v1/base_controller.rb`
  
- `app/controllers/api/v1/payments_controller.rb`  
  

- `app/controllers/api/v1/auths_controller.rb`
  Authentication controller with JWT and refresh token logic.

- `app/controllers/api/concerns/error_handler.rb`

- `config/routes/api.rb`  
  Modular API routes definition.

## Security & Anonymization

- All sensitive data, credentials, and business-specific names have been removed or anonymized.
- No real user or company data is included.

