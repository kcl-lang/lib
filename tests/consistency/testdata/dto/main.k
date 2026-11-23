schema User:
    """
    A user of the platform.

    Attributes
    ----------
    id : int, required
        The unique identifier.
    name : str, required
        The display name.
    nickname : str, optional
        An optional alias.
    score : float, default is 1.0
        A numeric score.
    active : bool, default is True
        Whether the account is active.
    """
    id: int
    name: str
    nickname?: str
    score?: float = 1.0
    active?: bool = True

schema Settings:
    """
    Runtime settings of the platform.

    Attributes
    ----------
    retries : int, default is 3
        How many times a failed request is retried.
    mode : str | int, default is "auto"
        The run mode.
    tags : [str], optional
        Free-form tags.
    labels : {str:str}, optional
        Free-form key-value labels.
    """
    retries: int = 3
    mode: str | int = "auto"
    tags?: [str]
    labels?: {str: str}
