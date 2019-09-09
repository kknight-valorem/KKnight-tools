# Set-Scopes.ps1

function Set-ScopeTest1 {
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (test) - 1
    Return $scope;
}
function Set-ScopeTest {
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (test) - 1
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (test) - 2
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (test) - 3
    Return $scope;
}
function Set-ScopeDev {
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (dev) - 1
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (dev) – 2
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (dev) – 3
    Return $scope;
}
function Set-ScopeAll {
    $scope = Set-ScopeDev;
    $scope = Set-ScopeTest;
    $scope = Set-ScopeProd;
    Return $scope;
}
function Set-ScopeProd {
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (prod) – 1
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (prod) – 2
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (prod) – 3
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (prod) – 4
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (prod) – 5
    $scope += '/subscriptions/a999a999-9a99-99aa-a9aa-9a99a99a999a' # Your subscription (prod) – 6
    Return $scope;
}