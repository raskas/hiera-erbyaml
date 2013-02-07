Introduction
============

Hiera is a configuration data store with pluggable back ends, hiera-erbyaml is a backend for hiera based on the yaml backend but extended with ERB parsing.

Why?
====

The yaml file, where the values are stored, is static, and in some cases you want a bit more flexibility.
When the value of a variable is parsed as an ERB template it adds more flexibility:
* calculations
* executing plain ruby code
* Accessing puppet variables
* Accessing puppet functions

Configuration
=============

<pre>
---
:backends: - erbyaml

:hierarchy: - %{env}
            - common

:yaml:
   :datadir: /etc/hiera/data
</pre>


The ERB-yaml backend is based on the yaml backend provided in puppet-3.0.2

Example
=======

<pre>
calculation:  '&lt;%= 12 + 1 %&gt;'
#  returns 13
puppet_var:   '&lt;%= scope.lookupvar("hostname") %&gt;'
#  returns the value of the puppet hostname variable (fact)
puppet_func:  '&lt;%= scope.function_md5(["foo"]) %&gt;'
#  returns the result of the md5 puppet function with argument "foo"
puppet_hiera: '&lt;%= scope.function_hiera(["calculation"]) %&gt;'
#  return the result of the hiera lookup with argument "calculation", in this case 13
</pre>

Contact
=======

* Author: Johan Huysmans
* Email: johan _DOT_ huysmans _AT_ inuits _DOT_ eu
* Twitter: @JohanHuysmans
