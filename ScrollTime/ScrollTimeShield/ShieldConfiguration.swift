import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Create a custom shield for blocked applications
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.95),
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(
                text: "Take a Moment",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "ScrollTime detected extended scrolling. Would you like to take a break?",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Take a Break",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Continue Anyway",
                color: .systemBlue
            )
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Shield configuration for category-based blocking
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.95),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(
                text: "Time for a Pause",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "You've been scrolling \(category.localizedDisplayName ?? "this category") for a while. Ready for a mindful break?",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Start Break",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemGreen,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "5 More Minutes",
                color: .systemGreen
            )
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "globe"),
            title: ShieldConfiguration.Label(
                text: "Mindful Browsing",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "ScrollTime suggests taking a break from this site.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Take a Break",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemIndigo,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Continue",
                color: .systemIndigo
            )
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "globe"),
            title: ShieldConfiguration.Label(
                text: "Web Break Time",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "You've spent significant time on \(category.localizedDisplayName ?? "web") sites.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Take a Break",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemPurple,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Continue",
                color: .systemPurple
            )
        )
    }
}
