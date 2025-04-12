import Foundation

final class ValidationManager {
    // MARK: - Properties
    static let shared = ValidationManager()
    
    private let analytics = AnalyticsManager.shared
    private var validationRules: [String: ValidationRule] = [:]
    private var customValidators: [String: CustomValidator] = [:]
    
    // MARK: - Types
    struct ValidationRule: Codable {
        let type: ValidationType
        let parameters: [String: Any]
        let errorMessage: String
        let severity: Severity
        
        enum ValidationType: String, Codable {
            case required
            case length
            case range
            case regex
            case email
            case username
            case password
            case date
            case numeric
            case custom
        }
        
        enum Severity: String, Codable {
            case warning
            case error
            case critical
        }
        
        private enum CodingKeys: String, CodingKey {
            case type
            case parameters
            case errorMessage
            case severity
        }
        
        init(
            type: ValidationType,
            parameters: [String: Any],
            errorMessage: String,
            severity: Severity = .error
        ) {
            self.type = type
            self.parameters = parameters
            self.errorMessage = errorMessage
            self.severity = severity
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(ValidationType.self, forKey: .type)
            parameters = try container.decode([String: String].self, forKey: .parameters)
            errorMessage = try container.decode(String.self, forKey: .errorMessage)
            severity = try container.decode(Severity.self, forKey: .severity)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(parameters as? [String: String] ?? [:], forKey: .parameters)
            try container.encode(errorMessage, forKey: .errorMessage)
            try container.encode(severity, forKey: .severity)
        }
    }
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let warnings: [ValidationError]
        
        static let valid = ValidationResult(isValid: true, errors: [], warnings: [])
    }
    
    struct ValidationError: LocalizedError {
        let field: String
        let message: String
        let severity: ValidationRule.Severity
        let code: String
        
        var errorDescription: String? {
            return message
        }
    }
    
    typealias CustomValidator = (String, [String: Any]) -> ValidationResult
    
    // MARK: - Initialization
    private init() {
        setupDefaultRules()
    }
    
    private func setupDefaultRules() {
        // Username validation
        validationRules["username"] = ValidationRule(
            type: .username,
            parameters: [
                "minLength": "3",
                "maxLength": "20",
                "pattern": "^[a-zA-Z0-9_-]*$"
            ],
            errorMessage: "Username must be 3-20 characters and contain only letters, numbers, underscores, and hyphens"
        )
        
        // Password validation
        validationRules["password"] = ValidationRule(
            type: .password,
            parameters: [
                "minLength": "8",
                "requireUppercase": "true",
                "requireLowercase": "true",
                "requireNumber": "true",
                "requireSpecial": "true"
            ],
            errorMessage: "Password must be at least 8 characters and contain uppercase, lowercase, number, and special character"
        )
        
        // Email validation
        validationRules["email"] = ValidationRule(
            type: .email,
            parameters: [
                "pattern": "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
            ],
            errorMessage: "Please enter a valid email address"
        )
        
        // Display name validation
        validationRules["displayName"] = ValidationRule(
            type: .length,
            parameters: [
                "minLength": "2",
                "maxLength": "30"
            ],
            errorMessage: "Display name must be 2-30 characters"
        )
        
        // Chat message validation
        validationRules["chatMessage"] = ValidationRule(
            type: .length,
            parameters: [
                "maxLength": "200"
            ],
            errorMessage: "Message cannot exceed 200 characters"
        )
        
        // Clan name validation
        validationRules["clanName"] = ValidationRule(
            type: .regex,
            parameters: [
                "pattern": "^[a-zA-Z0-9\\s]{3,20}$"
            ],
            errorMessage: "Clan name must be 3-20 characters and contain only letters, numbers, and spaces"
        )
    }
    
    // MARK: - Rule Management
    func addRule(_ rule: ValidationRule, forField field: String) {
        validationRules[field] = rule
    }
    
    func addCustomValidator(
        _ validator: @escaping CustomValidator,
        forType type: String
    ) {
        customValidators[type] = validator
    }
    
    // MARK: - Validation Methods
    func validate(
        _ value: String,
        field: String,
        type: ValidationRule.ValidationType? = nil
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationError] = []
        
        // Get rule for field or type
        guard let rule = type.map({ ValidationRule(
            type: $0,
            parameters: [:],
            errorMessage: "Validation failed"
        ) }) ?? validationRules[field] else {
            return .valid
        }
        
        // Perform validation based on type
        switch rule.type {
        case .required:
            if value.isEmpty {
                errors.append(ValidationError(
                    field: field,
                    message: rule.errorMessage,
                    severity: rule.severity,
                    code: "required"
                ))
            }
            
        case .length:
            let minLength = Int(rule.parameters["minLength"] as? String ?? "0") ?? 0
            let maxLength = Int(rule.parameters["maxLength"] as? String ?? "0") ?? Int.max
            
            if value.count < minLength || value.count > maxLength {
                errors.append(ValidationError(
                    field: field,
                    message: rule.errorMessage,
                    severity: rule.severity,
                    code: "length"
                ))
            }
            
        case .range:
            if let number = Double(value) {
                let min = Double(rule.parameters["min"] as? String ?? "-inf") ?? -Double.infinity
                let max = Double(rule.parameters["max"] as? String ?? "inf") ?? Double.infinity
                
                if number < min || number > max {
                    errors.append(ValidationError(
                        field: field,
                        message: rule.errorMessage,
                        severity: rule.severity,
                        code: "range"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    field: field,
                    message: "Value must be a number",
                    severity: rule.severity,
                    code: "numeric"
                ))
            }
            
        case .regex:
            if let pattern = rule.parameters["pattern"] as? String {
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(value.startIndex..., in: value)
                
                if regex?.firstMatch(in: value, range: range) == nil {
                    errors.append(ValidationError(
                        field: field,
                        message: rule.errorMessage,
                        severity: rule.severity,
                        code: "regex"
                    ))
                }
            }
            
        case .email:
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            
            if !emailPredicate.evaluate(with: value) {
                errors.append(ValidationError(
                    field: field,
                    message: rule.errorMessage,
                    severity: rule.severity,
                    code: "email"
                ))
            }
            
        case .username:
            let usernameRegex = "^[a-zA-Z0-9_-]{3,20}$"
            let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
            
            if !usernamePredicate.evaluate(with: value) {
                errors.append(ValidationError(
                    field: field,
                    message: rule.errorMessage,
                    severity: rule.severity,
                    code: "username"
                ))
            }
            
        case .password:
            let minLength = Int(rule.parameters["minLength"] as? String ?? "8") ?? 8
            let requireUppercase = (rule.parameters["requireUppercase"] as? String ?? "true") == "true"
            let requireLowercase = (rule.parameters["requireLowercase"] as? String ?? "true") == "true"
            let requireNumber = (rule.parameters["requireNumber"] as? String ?? "true") == "true"
            let requireSpecial = (rule.parameters["requireSpecial"] as? String ?? "true") == "true"
            
            if value.count < minLength {
                errors.append(ValidationError(
                    field: field,
                    message: "Password must be at least \(minLength) characters",
                    severity: rule.severity,
                    code: "password_length"
                ))
            }
            
            if requireUppercase && !value.contains(where: { $0.isUppercase }) {
                errors.append(ValidationError(
                    field: field,
                    message: "Password must contain an uppercase letter",
                    severity: rule.severity,
                    code: "password_uppercase"
                ))
            }
            
            if requireLowercase && !value.contains(where: { $0.isLowercase }) {
                errors.append(ValidationError(
                    field: field,
                    message: "Password must contain a lowercase letter",
                    severity: rule.severity,
                    code: "password_lowercase"
                ))
            }
            
            if requireNumber && !value.contains(where: { $0.isNumber }) {
                errors.append(ValidationError(
                    field: field,
                    message: "Password must contain a number",
                    severity: rule.severity,
                    code: "password_number"
                ))
            }
            
            if requireSpecial && !value.contains(where: { "!@#$%^&*(),.?\":{}|<>".contains($0) }) {
                errors.append(ValidationError(
                    field: field,
                    message: "Password must contain a special character",
                    severity: rule.severity,
                    code: "password_special"
                ))
            }
            
        case .date:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = rule.parameters["format"] as? String ?? "yyyy-MM-dd"
            
            if dateFormatter.date(from: value) == nil {
                errors.append(ValidationError(
                    field: field,
                    message: rule.errorMessage,
                    severity: rule.severity,
                    code: "date"
                ))
            }
            
        case .numeric:
            if Double(value) == nil {
                errors.append(ValidationError(
                    field: field,
                    message: rule.errorMessage,
                    severity: rule.severity,
                    code: "numeric"
                ))
            }
            
        case .custom:
            if let type = rule.parameters["type"] as? String,
               let validator = customValidators[type] {
                let result = validator(value, rule.parameters)
                errors.append(contentsOf: result.errors)
                warnings.append(contentsOf: result.warnings)
            }
        }
        
        let isValid = errors.isEmpty
        return ValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }
    
    func validateForm(_ fields: [String: String]) -> ValidationResult {
        var allErrors: [ValidationError] = []
        var allWarnings: [ValidationError] = []
        
        for (field, value) in fields {
            let result = validate(value, field: field)
            allErrors.append(contentsOf: result.errors)
            allWarnings.append(contentsOf: result.warnings)
        }
        
        return ValidationResult(
            isValid: allErrors.isEmpty,
            errors: allErrors,
            warnings: allWarnings
        )
    }
    
    // MARK: - Utility Methods
    func sanitize(_ input: String) -> String {
        // Remove potentially harmful characters
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return sanitized
    }
    
    func formatForDisplay(_ value: String, field: String) -> String {
        switch field {
        case "phone":
            // Format phone number
            let digits = value.filter { $0.isNumber }
            if digits.count == 10 {
                let index1 = digits.index(digits.startIndex, offsetBy: 3)
                let index2 = digits.index(digits.startIndex, offsetBy: 6)
                let part1 = digits[..<index1]
                let part2 = digits[index1..<index2]
                let part3 = digits[index2...]
                return "(\(part1)) \(part2)-\(part3)"
            }
            return value
            
        case "currency":
            // Format currency
            if let number = Double(value) {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                return formatter.string(from: NSNumber(value: number)) ?? value
            }
            return value
            
        default:
            return value
        }
    }
}

// MARK: - Convenience Methods
extension ValidationManager {
    func isValidEmail(_ email: String) -> Bool {
        return validate(email, field: "email").isValid
    }
    
    func isValidUsername(_ username: String) -> Bool {
        return validate(username, field: "username").isValid
    }
    
    func isValidPassword(_ password: String) -> Bool {
        return validate(password, field: "password").isValid
    }
    
    func getPasswordStrength(_ password: String) -> Int {
        var strength = 0
        
        if password.count >= 8 { strength += 1 }
        if password.contains(where: { $0.isUppercase }) { strength += 1 }
        if password.contains(where: { $0.isLowercase }) { strength += 1 }
        if password.contains(where: { $0.isNumber }) { strength += 1 }
        if password.contains(where: { "!@#$%^&*(),.?\":{}|<>".contains($0) }) { strength += 1 }
        
        return strength
    }
}
