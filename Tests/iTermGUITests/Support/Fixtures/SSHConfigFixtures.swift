import Foundation

enum SSHConfigFixtures {
    static let simpleConfig = """
    Host example
        HostName example.com
        User alex
        Port 2222
        IdentityFile ~/.ssh/id_rsa
    """

    static let wildcardConfig = """
    Host *
        ServerAliveInterval 60

    Host real-host
        HostName real.example.com
        User admin
    """

    static let portForwardConfig = """
    Host tunnel
        HostName bastion.example.com
        User forwarder
        LocalForward 8080 localhost:80
        RemoteForward 9090 internal:9090
    """

    static let colonForwardConfig = """
    Host tunnel
        HostName bastion.example.com
        LocalForward 8080:localhost:80
        RemoteForward 9090:internal:9090
    """

    static let malformedForwardConfig = """
    Host tunnel
        HostName bastion.example.com
        LocalForward 8080
    """

    static let multiHostConfig = """
    # Top of config
    Host a
        HostName a.example.com
        User alice
        Compression yes

    Host b
        HostName b.example.com
        User bob
        StrictHostKeyChecking no

    # comment between hosts
    Host c
        HostName c.example.com
        ProxyJump jump.example.com
        ProxyCommand nc -X connect -x proxy:3128 %h %p
    """

    static let emptyConfig = ""

    static let commentsOnlyConfig = """
    # this is a comment
    # this is another comment
    """

    static let invalidPortConfig = """
    Host broken
        HostName example.com
        Port not-a-port
        ConnectTimeout NaN
    """

    static let bothKeysConfig = """
    Host keyed
        HostName example.com
        IdentityFile ~/.ssh/custom_id
    """
}
