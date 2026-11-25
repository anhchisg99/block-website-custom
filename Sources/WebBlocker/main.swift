import Foundation

// The same binary serves two roles:
//   WebBlocker                         → the SwiftUI app
//   webblockerd --apply <config.json>  → run by launchd as root, syncs /etc/hosts with the schedule
//   webblockerd --clear                → removes all WebBlocker entries from /etc/hosts
let args = CommandLine.arguments
if args.count == 3, args[1] == "--apply" {
    exit(Daemon.apply(configPath: args[2]))
}
if args.count == 2, args[1] == "--clear" {
    exit(Daemon.writeHosts(blocking: []))
}
WebBlockerApp.main()
