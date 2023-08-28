## Overview
Each user is a member of 0 or more permission sets, these control the actions able to be taken by the user. They are controlled from the Central Admin section `/admin/users/<id>`. When on this page you can select the `#permissions` tab and then Edit permissions for the user. You will only ever be able to assign permissions relative to your own.

Permissions are built from 3 parts e.g. `logging.audit.show`. If you have one part of a permission you have all lower parts so in the previous example you have both `logging.audit` and `logging` permissions.

Teiserver is built on the Central template and has thus already got the following permission groups `admin`, `communication` and `logging`. Teiserver adds an extra group `teiserver` where all Teiserver specific permissions will sit.

In summary:
- Permissions limit what you can do with data
- Groups limit what data you can access

### Teiserver sections
`lib/teiserver/startup.ex` defines the permissions used by Teiserver (preceded by a comment saying `# Permissions setup` and are grouped accordingly:
- Admin: Server and game management, has complete control over any portion of the Teiserver server components
- Moderator: Ability to view things such as chat logs and perform moderation actions. This is being depreciated in favour of the Staff item.
- Staff: Allows a role to be performed without giving access to sensitive information
- Reports: Ability to view server reporting features. Note some other sections may grant access to the reporting area but the reports permission is required to access many of the specific reports
- API: Allows for access to the REST API, barely started and possibly to be discarded in the future depending on demand
- Player: Used to mark an account as being a Teiserver account, may also be discontinued in the future

Each of these sections subdivides further (e.g. admin has account, battle and queue permissions).
